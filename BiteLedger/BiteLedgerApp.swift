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
