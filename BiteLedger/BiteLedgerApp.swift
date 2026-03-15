//
//  BiteLedgerApp.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData
import CoreData

@main
struct BiteLedgerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            FoodLog.self,
            ServingSize.self,
            UserPreferences.self,
            Recipe.self,
            RecipeIngredient.self,
            CanonicalFood.self,
            ServingConversion.self,
            FallbackSource.self,
        ])

        // cloudKitDatabase: .none is required — even though we don't use CloudKit,
        // the capability being present in the entitlements causes SwiftData to attempt
        // CloudKit integration unless explicitly disabled.
        //
        // Adding optional properties (like `unit: String?` on ServingSize) is handled
        // automatically by SwiftData as a lightweight SQLite column addition — no
        // migration plan needed. See BiteLedgerSchema.swift for when to add one.
        //
        // Never revert to delete-and-recreate — that destroys user data.
        do {
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SafeContentView(modelContainer: sharedModelContainer)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct SafeContentView: View {
    let modelContainer: ModelContainer

    var body: some View {
        ContentView()
            .task {
                await backfillServingUnits(container: modelContainer)
                await backfillStaleLogs(container: modelContainer)
                await backfillServingAmounts(container: modelContainer)
                await normalizeExistingPerServingFoods(container: modelContainer)
                await backfillFoodLogGramAmounts(container: modelContainer)
                await CanonicalFoodSeeder.seedIfNeeded(container: modelContainer)
            }
    }
}

/// Backfill for servings whose `unit` field is stale after a label edit.
///
/// When FoodItemEditorView changed a serving label from "g" to e.g. "1 cup" but
/// didn't update the `unit` field, `unit` stays "g" while `gramWeight` is now 42.
/// `FoodLogEditView.resolvedQuantity` then reads `unit="g"` and thinks the serving
/// is still gram-based, returning the raw gram count (60) as serving count → 9,600 cal.
///
/// Fix:
/// 1. Update `serving.unit` to match the parsed label.
/// 2. If logs stored quantity as grams (1 serving = 1g), rescale to new serving count.
///
/// Safe to run on every launch — the condition (unit="g" AND gramWeight>1 AND
/// label parses to non-gram) is false after the fix, so subsequent runs are no-ops.
@MainActor
private func backfillStaleLogs(container: ModelContainer) async {
    let context = container.mainContext
    do {
        let allServings = try context.fetch(FetchDescriptor<ServingSize>())
        let stale = allServings.filter { serving in
            // Must have unit="g" (gram) — indicates a gram-based origin
            guard serving.unit == ServingUnit.gram.rawValue,
                  let gw = serving.gramWeight, gw > 1 else { return false }
            // Label must parse to a non-gram unit — label was edited away from "g"
            let parsedUnit = ServingSizeParser.parse(serving.label)?.unit
                          ?? ServingSizeParser.parseUnit(serving.label)
            return parsedUnit != nil && parsedUnit != .gram && parsedUnit != .serving
        }
        guard !stale.isEmpty else { return }

        for serving in stale {
            guard let newGW = serving.gramWeight, newGW > 1 else { continue }
            let parsedUnit = ServingSizeParser.parse(serving.label)?.unit
                          ?? ServingSizeParser.parseUnit(serving.label)
            if let pu = parsedUnit {
                serving.unit = pu.rawValue
            }
            // Rescale any FoodLog.quantity that was stored as grams
            let servingId = serving.id
            let logs = try context.fetch(FetchDescriptor<FoodLog>(
                predicate: #Predicate { $0.servingSize?.id == servingId }
            ))
            for log in logs {
                log.quantity = log.quantity / newGW
            }
        }
        try context.save()
        print("✅ backfillStaleLogs: fixed \(stale.count) serving(s)")
    } catch {
        print("⚠️ backfillStaleLogs failed: \(error)")
    }
}

/// One-time migration: converts all perServing FoodItems to per100g in place.
///
/// Resolution order for gramWeightPerServing:
///   1. defaultServing.gramWeight (actual gram weight set at import time)
///   2. Density table estimate from unit + food name (volume foods)
///   3. 100g nominal — values unchanged, serving gramWeight set to 100
///
/// Safe to run on every launch — skips foods already in per100g mode.
/// Must run BEFORE backfillFoodLogGramAmounts so servings have gramWeight set.
@MainActor
private func normalizeExistingPerServingFoods(container: ModelContainer) async {
    let context = container.mainContext
    do {
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let perServingFoods = foods.filter { $0.nutritionMode == .perServing }
        guard !perServingFoods.isEmpty else { return }

        for food in perServingFoods {
            let defaultServing = food.defaultServing

            // Determine effective gram weight
            let gramWeight: Double?
            if let gw = defaultServing?.gramWeight, gw > 0 {
                gramWeight = gw
            } else if let unitStr = defaultServing?.unit,
                      let su = ServingUnit.fromAbbreviation(unitStr),
                      su != .serving, su != .container {
                let amount = defaultServing?.amount ?? 1.0
                let density = ServingUnit.densityFor(foodType: FoodType.infer(from: food.name))
                let estimated = su.toGrams(amount: amount, density: density)
                gramWeight = estimated > 0 ? estimated : nil
            } else {
                gramWeight = nil  // will use 100g nominal
            }

            let effectiveGrams = gramWeight ?? 100.0
            food.normalizeToPerHundredGrams(gramWeightPerServing: gramWeight)

            // Ensure all servings for this food have gramWeight set
            if let serving = defaultServing, serving.gramWeight == nil {
                serving.gramWeight = effectiveGrams
            }
        }
        try context.save()
        print("✅ normalizeExistingPerServingFoods: normalized \(perServingFoods.count) food(s)")
    } catch {
        print("⚠️ normalizeExistingPerServingFoods failed: \(error)")
    }
}

/// Backfill `ServingSize.amount` from the label parser for all records where amount == 1.0.
/// Idempotent — parser result of 1.0 leaves the field unchanged.
/// Runs on every launch but is a no-op after all records are correct.
@MainActor
private func backfillServingAmounts(container: ModelContainer) async {
    let context = container.mainContext
    do {
        let servings = try context.fetch(FetchDescriptor<ServingSize>())
        var changed = 0
        for serving in servings {
            if let parsed = ServingSizeParser.parse(serving.label),
               parsed.amount != serving.amount {
                serving.amount = parsed.amount
                changed += 1
            }
        }
        if changed > 0 {
            try context.save()
            print("✅ backfillServingAmounts: updated \(changed) serving(s)")
        }
    } catch {
        print("⚠️ backfillServingAmounts failed: \(error)")
    }
}

/// Backfill `FoodLog.gramAmount` for logs created before schema V3.
/// Uses quantity × servingSize.gramWeight. Falls back to 100g/serving for no-gram foods.
/// Safe to run on every launch — skips logs where gramAmount is already non-zero.
@MainActor
private func backfillFoodLogGramAmounts(container: ModelContainer) async {
    let context = container.mainContext
    do {
        let logs = try context.fetch(FetchDescriptor<FoodLog>())
        let unset = logs.filter { $0.gramAmount == 0 }
        guard !unset.isEmpty else { return }
        for log in unset {
            let resolvedServing = log.servingSize ?? log.foodItem?.defaultServing
            if let gw = resolvedServing?.gramWeight {
                log.gramAmount = log.quantity * gw
            } else {
                // No gram data — try density-based estimate from unit
                let unitStr = resolvedServing?.unit ?? log.loggedUnit
                let servingUnit = unitStr.flatMap { ServingUnit.fromAbbreviation($0) }
                if let su = servingUnit {
                    let amount = resolvedServing?.amount ?? log.loggedAmount ?? 1.0
                    let density = ServingUnit.densityFor(
                        foodType: FoodType.infer(from: log.foodItem?.name ?? "")
                    )
                    log.gramAmount = su.toGrams(amount: amount * log.quantity, density: density)
                } else {
                    log.gramAmount = log.quantity * 100
                }
            }
            // Also backfill loggedAmount/loggedUnit if missing
            if log.loggedAmount == nil { log.loggedAmount = log.quantity }
            if log.loggedUnit == nil { log.loggedUnit = resolvedServing?.unit }
        }
        try context.save()
        print("✅ backfillFoodLogGramAmounts: set gramAmount on \(unset.count) log(s)")
    } catch {
        print("⚠️ backfillFoodLogGramAmounts failed: \(error)")
    }
}

/// One-time backfill: populate `unit` on ServingSize records created before schema V2.
/// Safe to run on every launch — skips records that already have a unit set.
@MainActor
private func backfillServingUnits(container: ModelContainer) async {
    let context = container.mainContext
    do {
        let servings = try context.fetch(
            FetchDescriptor<ServingSize>(
                predicate: #Predicate { $0.unit == nil }
            )
        )
        guard !servings.isEmpty else { return }
        for serving in servings {
            if let parsed = ServingSizeParser.parse(serving.label),
               parsed.unit != .serving {
                serving.unit = parsed.unit.rawValue
            } else if let unit = ServingSizeParser.parseUnit(serving.label) {
                serving.unit = unit.rawValue
            }
        }
        try context.save()
        print("✅ Backfilled unit on \(servings.count) ServingSize records")
    } catch {
        print("⚠️ backfillServingUnits failed: \(error)")
    }
}
