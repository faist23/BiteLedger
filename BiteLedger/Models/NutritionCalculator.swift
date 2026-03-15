//
//  NutritionCalculator.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/27/26.
//


import Foundation

// MARK: - NutritionCalculator
//
// THIS IS THE ONLY PLACE NUTRITION MATH IS PERFORMED.
//
// Rules:
//   - Views never calculate nutrition
//   - Pickers never calculate nutrition
//   - Models never calculate nutrition
//   - Extensions never calculate nutrition
//   - Only this file calculates nutrition
//
// Single formula (Phase 2+):
//   nutrition = (gramAmount / 100) × nutrientPer100g
//
// gramAmount is the number of grams consumed. For all foods:
//   - per100g foods with gramWeight:  gramAmount = quantity × gramWeight
//   - perServing foods (transitional): gramAmount = quantity × 100 (nominal, until Phase 3 normalizes)
//
// Usage:
//   // From a log already created:
//   let result = NutritionCalculator.fromLog(log)
//
//   // Live preview in a picker (not stored):
//   let result = NutritionCalculator.preview(food: food, serving: serving, quantity: 1.5)
//
//   // Creating a new FoodLog (pass pre-computed gramAmount):
//   let result = NutritionCalculator.calculate(food: food, gramAmount: 240.0)

struct NutritionCalculator {

    // MARK: - Result

    struct Result {
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double?
        var sugar: Double?
        var saturatedFat: Double?
        var transFat: Double?
        var monounsaturatedFat: Double?
        var polyunsaturatedFat: Double?
        var sodium: Double?
        var cholesterol: Double?
        var potassium: Double?
        var calcium: Double?
        var iron: Double?
        var magnesium: Double?
        var zinc: Double?
        var vitaminA: Double?
        var vitaminC: Double?
        var vitaminD: Double?
        var vitaminE: Double?
        var vitaminK: Double?
        var vitaminB6: Double?
        var vitaminB12: Double?
        var folate: Double?
        var choline: Double?
        var caffeine: Double?

        static var zero: Result {
            Result(calories: 0, protein: 0, carbs: 0, fat: 0)
        }

        /// Adds two results together (for daily totals).
        static func + (lhs: Result, rhs: Result) -> Result {
            Result(
                calories:            lhs.calories + rhs.calories,
                protein:             lhs.protein + rhs.protein,
                carbs:               lhs.carbs + rhs.carbs,
                fat:                 lhs.fat + rhs.fat,
                fiber:               add(lhs.fiber, rhs.fiber),
                sugar:               add(lhs.sugar, rhs.sugar),
                saturatedFat:        add(lhs.saturatedFat, rhs.saturatedFat),
                transFat:            add(lhs.transFat, rhs.transFat),
                monounsaturatedFat:  add(lhs.monounsaturatedFat, rhs.monounsaturatedFat),
                polyunsaturatedFat:  add(lhs.polyunsaturatedFat, rhs.polyunsaturatedFat),
                sodium:              add(lhs.sodium, rhs.sodium),
                cholesterol:         add(lhs.cholesterol, rhs.cholesterol),
                potassium:           add(lhs.potassium, rhs.potassium),
                calcium:             add(lhs.calcium, rhs.calcium),
                iron:                add(lhs.iron, rhs.iron),
                magnesium:           add(lhs.magnesium, rhs.magnesium),
                zinc:                add(lhs.zinc, rhs.zinc),
                vitaminA:            add(lhs.vitaminA, rhs.vitaminA),
                vitaminC:            add(lhs.vitaminC, rhs.vitaminC),
                vitaminD:            add(lhs.vitaminD, rhs.vitaminD),
                vitaminE:            add(lhs.vitaminE, rhs.vitaminE),
                vitaminK:            add(lhs.vitaminK, rhs.vitaminK),
                vitaminB6:           add(lhs.vitaminB6, rhs.vitaminB6),
                vitaminB12:          add(lhs.vitaminB12, rhs.vitaminB12),
                folate:              add(lhs.folate, rhs.folate),
                choline:             add(lhs.choline, rhs.choline),
                caffeine:            add(lhs.caffeine, rhs.caffeine)
            )
        }

        /// Scales all nutrition values by a factor (e.g., 1/yield for per-serving conversion).
        func scaled(by factor: Double) -> Result {
            Result(
                calories:            calories * factor,
                protein:             protein * factor,
                carbs:               carbs * factor,
                fat:                 fat * factor,
                fiber:               fiber.map { $0 * factor },
                sugar:               sugar.map { $0 * factor },
                saturatedFat:        saturatedFat.map { $0 * factor },
                transFat:            transFat.map { $0 * factor },
                monounsaturatedFat:  monounsaturatedFat.map { $0 * factor },
                polyunsaturatedFat:  polyunsaturatedFat.map { $0 * factor },
                sodium:              sodium.map { $0 * factor },
                cholesterol:         cholesterol.map { $0 * factor },
                potassium:           potassium.map { $0 * factor },
                calcium:             calcium.map { $0 * factor },
                iron:                iron.map { $0 * factor },
                magnesium:           magnesium.map { $0 * factor },
                zinc:                zinc.map { $0 * factor },
                vitaminA:            vitaminA.map { $0 * factor },
                vitaminC:            vitaminC.map { $0 * factor },
                vitaminD:            vitaminD.map { $0 * factor },
                vitaminE:            vitaminE.map { $0 * factor },
                vitaminK:            vitaminK.map { $0 * factor },
                vitaminB6:           vitaminB6.map { $0 * factor },
                vitaminB12:          vitaminB12.map { $0 * factor },
                folate:              folate.map { $0 * factor },
                choline:             choline.map { $0 * factor },
                caffeine:            caffeine.map { $0 * factor }
            )
        }

        private static func add(_ a: Double?, _ b: Double?) -> Double? {
            switch (a, b) {
            case let (x?, y?): return x + y
            case let (x?, nil): return x
            case let (nil, y?): return y
            default: return nil
            }
        }
    }

    // MARK: - Primary Calculation (gram-based)

    /// The canonical calculation method. Call this when creating a new FoodLog.
    ///
    /// Single formula: `(gramAmount / 100) × nutrientPer100g`
    ///
    /// All FoodItem nutrition fields store per-100g values. For perServing foods that
    /// haven't been normalized yet (Phase 3), gramAmount is computed as quantity × 100
    /// (nominal), which preserves the same result as the legacy perServing formula.
    ///
    /// - Parameters:
    ///   - food:       The FoodItem. All nutrition fields are treated as per-100g.
    ///   - gramAmount: Total grams consumed (quantity × serving gramWeight, or estimated).
    static func calculate(food: FoodItem, gramAmount: Double) -> Result {
        guard gramAmount > 0 else { return .zero }
        let factor = gramAmount / 100.0
        return Result(
            calories:            food.calories * factor,
            protein:             food.protein * factor,
            carbs:               food.carbs * factor,
            fat:                 food.fat * factor,
            fiber:               food.fiber.map { $0 * factor },
            sugar:               food.sugar.map { $0 * factor },
            saturatedFat:        food.saturatedFat.map { $0 * factor },
            transFat:            food.transFat.map { $0 * factor },
            monounsaturatedFat:  food.monounsaturatedFat.map { $0 * factor },
            polyunsaturatedFat:  food.polyunsaturatedFat.map { $0 * factor },
            sodium:              food.sodium.map { $0 * factor },
            cholesterol:         food.cholesterol.map { $0 * factor },
            potassium:           food.potassium.map { $0 * factor },
            calcium:             food.calcium.map { $0 * factor },
            iron:                food.iron.map { $0 * factor },
            magnesium:           food.magnesium.map { $0 * factor },
            zinc:                food.zinc.map { $0 * factor },
            vitaminA:            food.vitaminA.map { $0 * factor },
            vitaminC:            food.vitaminC.map { $0 * factor },
            vitaminD:            food.vitaminD.map { $0 * factor },
            vitaminE:            food.vitaminE.map { $0 * factor },
            vitaminK:            food.vitaminK.map { $0 * factor },
            vitaminB6:           food.vitaminB6.map { $0 * factor },
            vitaminB12:          food.vitaminB12.map { $0 * factor },
            folate:              food.folate.map { $0 * factor },
            choline:             food.choline.map { $0 * factor },
            caffeine:            food.caffeine.map { $0 * factor }
        )
    }

    // MARK: - Calculate from FoodLog (reads frozen values)

    /// Returns frozen nutrition from an existing FoodLog.
    /// Use this when displaying logged entries. Never recalculate from the food.
    static func fromLog(_ log: FoodLog) -> Result {
        Result(
            calories:            log.caloriesAtLogTime,
            protein:             log.proteinAtLogTime,
            carbs:               log.carbsAtLogTime,
            fat:                 log.fatAtLogTime,
            fiber:               log.fiberAtLogTime,
            sugar:               log.sugarAtLogTime,
            saturatedFat:        log.saturatedFatAtLogTime,
            transFat:            log.transFatAtLogTime,
            monounsaturatedFat:  log.monounsaturatedFatAtLogTime,
            polyunsaturatedFat:  log.polyunsaturatedFatAtLogTime,
            sodium:              log.sodiumAtLogTime,
            cholesterol:         log.cholesterolAtLogTime,
            potassium:           log.potassiumAtLogTime,
            calcium:             log.calciumAtLogTime,
            iron:                log.ironAtLogTime,
            magnesium:           log.magnesiumAtLogTime,
            zinc:                log.zincAtLogTime,
            vitaminA:            log.vitaminAAtLogTime,
            vitaminC:            log.vitaminCAtLogTime,
            vitaminD:            log.vitaminDAtLogTime,
            vitaminE:            log.vitaminEAtLogTime,
            vitaminK:            log.vitaminKAtLogTime,
            vitaminB6:           log.vitaminB6AtLogTime,
            vitaminB12:          log.vitaminB12AtLogTime,
            folate:              log.folateAtLogTime,
            choline:             log.cholineAtLogTime,
            caffeine:            log.caffeineAtLogTime
        )
    }

    // MARK: - Daily Totals

    /// Sums nutrition across multiple FoodLogs for a given day.
    /// Always reads frozen AtLogTime values — never recalculates.
    static func dailyTotal(logs: [FoodLog]) -> Result {
        logs.reduce(.zero) { total, log in
            total + fromLog(log)
        }
    }

    /// Sums nutrition for a specific meal type.
    static func mealTotal(logs: [FoodLog], mealType: MealType) -> Result {
        dailyTotal(logs: logs.filter { $0.mealType == mealType })
    }

    // MARK: - Preview (for serving pickers, before logging)

    /// Calculates nutrition for display in a serving picker or live edit view.
    /// This result is NOT stored — it's only for live preview in the UI.
    ///
    /// Computes gramAmount from serving + quantity, then delegates to `calculate(food:gramAmount:)`.
    static func preview(
        food: FoodItem,
        serving: ServingSize?,
        quantity: Double
    ) -> Result {
        let gramAmount = resolveGramAmount(food: food, serving: serving, quantity: quantity)
        return calculate(food: food, gramAmount: gramAmount)
    }

    /// Transitional alias so existing view callers of `calculate(food:serving:quantity:)`
    /// continue to compile unchanged. Equivalent to `preview()`.
    ///
    /// Prefer `preview()` at call sites — the name makes clear the result is not stored.
    static func calculate(
        food: FoodItem,
        serving: ServingSize?,
        quantity: Double
    ) -> Result {
        preview(food: food, serving: serving, quantity: quantity)
    }

    // MARK: - Recipe Nutrition

    /// Calculates per-serving nutrition for a recipe by summing all ingredients
    /// and dividing by the recipe's servings yield.
    ///
    /// Call this when saving or editing a recipe to write nutrition onto its FoodItem.
    /// Ingredients whose `foodItem` is nil (deleted food) are skipped.
    ///
    /// - Parameters:
    ///   - ingredients: The recipe's ingredient list.
    ///   - yield: How many servings the recipe makes.
    /// - Returns: Per-serving nutrition for the whole recipe.
    static func calculateRecipeNutrition(
        ingredients: [RecipeIngredient],
        yield: Double
    ) -> Result {
        guard yield > 0 else { return .zero }
        let total = ingredients.reduce(Result.zero) { sum, ingredient in
            guard let food = ingredient.foodItem else { return sum }
            return sum + preview(food: food, serving: ingredient.servingSize, quantity: ingredient.quantity)
        }
        return total.scaled(by: 1.0 / yield)
    }

    // MARK: - Private Helpers

    /// Converts food + serving + quantity into a gram amount for `calculate(food:gramAmount:)`.
    ///
    /// Resolution order:
    ///   1. serving.gramWeight (or defaultServing.gramWeight) × quantity — exact
    ///   2. Density table estimate when unit is known but gramWeight is nil
    ///   3. quantity × 100 nominal (perServing foods without gram data, until Phase 3)
    ///
    /// Called by `FoodLog.create()` and `preview()`. Not private so the factory can call it.
    static func resolveGramAmount(
        food: FoodItem,
        serving: ServingSize?,
        quantity: Double
    ) -> Double {
        guard quantity > 0 else { return 0 }
        let resolvedServing = serving ?? food.defaultServing

        // Path 1: gram weight known — exact
        if let gw = resolvedServing?.gramWeight {
            return quantity * gw
        }

        // Path 2: unit known — density estimate
        let unitStr = resolvedServing?.unit
        if let unitStr,
           let su = ServingUnit.fromAbbreviation(unitStr),
           su != .serving, su != .container {
            let amount = resolvedServing?.amount ?? 1.0
            let density = ServingUnit.densityFor(foodType: FoodType.infer(from: food.name))
            return su.toGrams(amount: amount * quantity, density: density)
        }

        // Path 3: no gram data — 100g/serving nominal (perServing transitional)
        // Math: (quantity × 100 / 100) × nutrient = quantity × nutrient ≡ old scaledPerServing
        return quantity * 100.0
    }
}
