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
// Usage:
//   let result = NutritionCalculator.calculate(food: food, serving: serving, quantity: 1.5)
//   label.text = "\(result.calories) kcal"

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

        private static func add(_ a: Double?, _ b: Double?) -> Double? {
            switch (a, b) {
            case let (x?, y?): return x + y
            case let (x?, nil): return x
            case let (nil, y?): return y
            default: return nil
            }
        }
    }

    // MARK: - Calculate from FoodItem + ServingSize

    /// The primary calculation method. Call this when creating a new FoodLog.
    ///
    /// - Parameters:
    ///   - food: The FoodItem being logged.
    ///   - serving: The ServingSize selected. nil = use food's default serving.
    ///   - quantity: Number of servings (e.g., 1.5 = one and a half servings).
    /// - Returns: Calculated nutrition for the full quantity.
    static func calculate(
        food: FoodItem,
        serving: ServingSize?,
        quantity: Double
    ) -> Result {
        guard quantity > 0 else { return .zero }

        let resolvedServing = serving ?? food.defaultServing

        switch food.nutritionMode {

        case .per100g:
            // Need gram weight to calculate correctly
            if let grams = resolvedServing?.gramWeight {
                return scaledPer100g(food: food, grams: grams, quantity: quantity)
            } else {
                // per100g food but no gram weight available.
                // This should not happen for properly imported foods.
                // Fall through to perServing as a safe fallback.
                return scaledPerServing(food: food, quantity: quantity)
            }

        case .perServing:
            // Nutrition values ARE the per-serving values. Scale by quantity only.
            return scaledPerServing(food: food, quantity: quantity)
        }
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

    /// Calculates nutrition for display in a serving picker.
    /// This result is NOT stored — it's only for live preview in the UI.
    static func preview(
        food: FoodItem,
        serving: ServingSize?,
        quantity: Double
    ) -> Result {
        calculate(food: food, serving: serving, quantity: quantity)
    }

    // MARK: - Private Helpers

    private static func scaledPer100g(
        food: FoodItem,
        grams: Double,
        quantity: Double
    ) -> Result {
        let factor = (grams / 100.0) * quantity
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

    private static func scaledPerServing(
        food: FoodItem,
        quantity: Double
    ) -> Result {
        Result(
            calories:            food.calories * quantity,
            protein:             food.protein * quantity,
            carbs:               food.carbs * quantity,
            fat:                 food.fat * quantity,
            fiber:               food.fiber.map { $0 * quantity },
            sugar:               food.sugar.map { $0 * quantity },
            saturatedFat:        food.saturatedFat.map { $0 * quantity },
            transFat:            food.transFat.map { $0 * quantity },
            monounsaturatedFat:  food.monounsaturatedFat.map { $0 * quantity },
            polyunsaturatedFat:  food.polyunsaturatedFat.map { $0 * quantity },
            sodium:              food.sodium.map { $0 * quantity },
            cholesterol:         food.cholesterol.map { $0 * quantity },
            potassium:           food.potassium.map { $0 * quantity },
            calcium:             food.calcium.map { $0 * quantity },
            iron:                food.iron.map { $0 * quantity },
            magnesium:           food.magnesium.map { $0 * quantity },
            zinc:                food.zinc.map { $0 * quantity },
            vitaminA:            food.vitaminA.map { $0 * quantity },
            vitaminC:            food.vitaminC.map { $0 * quantity },
            vitaminD:            food.vitaminD.map { $0 * quantity },
            vitaminE:            food.vitaminE.map { $0 * quantity },
            vitaminK:            food.vitaminK.map { $0 * quantity },
            vitaminB6:           food.vitaminB6.map { $0 * quantity },
            vitaminB12:          food.vitaminB12.map { $0 * quantity },
            folate:              food.folate.map { $0 * quantity },
            choline:             food.choline.map { $0 * quantity },
            caffeine:            food.caffeine.map { $0 * quantity }
        )
    }
}