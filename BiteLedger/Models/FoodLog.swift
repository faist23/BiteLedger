//
//  FoodLog.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftData
import Foundation

// MARK: - FoodLog

@Model
final class FoodLog {

    // MARK: Identity
    var id: UUID
    var timestamp: Date
    var mealType: MealType

    // MARK: Quantity
    /// Number of servings logged. e.g., 1.5 means 1.5 × the selected ServingSize.
    var quantity: Double

    // MARK: Relationships
    /// The food that was eaten. Nullified (not deleted) if food is removed.
    var foodItem: FoodItem?

    /// The specific serving size used. nil means the food's default serving was used.
    var servingSize: ServingSize?

    // MARK: Frozen Nutrition — SET ONCE AT LOG TIME, NEVER RECALCULATED
    //
    // These values are calculated by NutritionCalculator at the moment the user
    // confirms the log entry and are NEVER updated afterward.
    //
    // This ensures that editing a FoodItem later does not rewrite log history.
    // Always read these fields when displaying a logged entry's nutrition.
    // Never call NutritionCalculator on a FoodLog that already exists.

    var caloriesAtLogTime: Double
    var proteinAtLogTime: Double
    var carbsAtLogTime: Double
    var fatAtLogTime: Double
    var fiberAtLogTime: Double?
    var sodiumAtLogTime: Double?
    var sugarAtLogTime: Double?
    var saturatedFatAtLogTime: Double?
    var transFatAtLogTime: Double?
    var monounsaturatedFatAtLogTime: Double?
    var polyunsaturatedFatAtLogTime: Double?
    var cholesterolAtLogTime: Double?
    var potassiumAtLogTime: Double?
    var calciumAtLogTime: Double?
    var ironAtLogTime: Double?
    var magnesiumAtLogTime: Double?
    var zincAtLogTime: Double?
    var vitaminAAtLogTime: Double?
    var vitaminCAtLogTime: Double?
    var vitaminDAtLogTime: Double?
    var vitaminEAtLogTime: Double?
    var vitaminKAtLogTime: Double?
    var vitaminB6AtLogTime: Double?
    var vitaminB12AtLogTime: Double?
    var folateAtLogTime: Double?
    var cholineAtLogTime: Double?
    var caffeineAtLogTime: Double?

    // MARK: Init
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        mealType: MealType,
        quantity: Double,
        foodItem: FoodItem? = nil,
        servingSize: ServingSize? = nil,
        caloriesAtLogTime: Double,
        proteinAtLogTime: Double,
        carbsAtLogTime: Double,
        fatAtLogTime: Double,
        fiberAtLogTime: Double? = nil,
        sodiumAtLogTime: Double? = nil,
        sugarAtLogTime: Double? = nil,
        saturatedFatAtLogTime: Double? = nil,
        transFatAtLogTime: Double? = nil,
        monounsaturatedFatAtLogTime: Double? = nil,
        polyunsaturatedFatAtLogTime: Double? = nil,
        cholesterolAtLogTime: Double? = nil,
        potassiumAtLogTime: Double? = nil,
        calciumAtLogTime: Double? = nil,
        ironAtLogTime: Double? = nil,
        magnesiumAtLogTime: Double? = nil,
        zincAtLogTime: Double? = nil,
        vitaminAAtLogTime: Double? = nil,
        vitaminCAtLogTime: Double? = nil,
        vitaminDAtLogTime: Double? = nil,
        vitaminEAtLogTime: Double? = nil,
        vitaminKAtLogTime: Double? = nil,
        vitaminB6AtLogTime: Double? = nil,
        vitaminB12AtLogTime: Double? = nil,
        folateAtLogTime: Double? = nil,
        cholineAtLogTime: Double? = nil,
        caffeineAtLogTime: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mealType = mealType
        self.quantity = quantity
        self.foodItem = foodItem
        self.servingSize = servingSize
        self.caloriesAtLogTime = caloriesAtLogTime
        self.proteinAtLogTime = proteinAtLogTime
        self.carbsAtLogTime = carbsAtLogTime
        self.fatAtLogTime = fatAtLogTime
        self.fiberAtLogTime = fiberAtLogTime
        self.sodiumAtLogTime = sodiumAtLogTime
        self.sugarAtLogTime = sugarAtLogTime
        self.saturatedFatAtLogTime = saturatedFatAtLogTime
        self.transFatAtLogTime = transFatAtLogTime
        self.monounsaturatedFatAtLogTime = monounsaturatedFatAtLogTime
        self.polyunsaturatedFatAtLogTime = polyunsaturatedFatAtLogTime
        self.cholesterolAtLogTime = cholesterolAtLogTime
        self.potassiumAtLogTime = potassiumAtLogTime
        self.calciumAtLogTime = calciumAtLogTime
        self.ironAtLogTime = ironAtLogTime
        self.magnesiumAtLogTime = magnesiumAtLogTime
        self.zincAtLogTime = zincAtLogTime
        self.vitaminAAtLogTime = vitaminAAtLogTime
        self.vitaminCAtLogTime = vitaminCAtLogTime
        self.vitaminDAtLogTime = vitaminDAtLogTime
        self.vitaminEAtLogTime = vitaminEAtLogTime
        self.vitaminKAtLogTime = vitaminKAtLogTime
        self.vitaminB6AtLogTime = vitaminB6AtLogTime
        self.vitaminB12AtLogTime = vitaminB12AtLogTime
        self.folateAtLogTime = folateAtLogTime
        self.cholineAtLogTime = cholineAtLogTime
        self.caffeineAtLogTime = caffeineAtLogTime
    }

    // MARK: Computed Display Helpers

    var servingLabel: String {
        servingSize?.label ?? foodItem?.defaultServing?.label ?? "1 serving"
    }

    var quantityDescription: String {
        // Calculate the actual gram amount if we have gram weight
        if let gramWeight = servingSize?.gramWeight {
            let totalGrams = quantity * gramWeight
            
            // Format total grams nicely
            let gramsText = totalGrams.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(totalGrams))
                : String(format: "%.1f", totalGrams)
            
            // If serving label is just a unit (g, oz, cup, etc.), show as "88 g" not "88 × g"
            let label = servingLabel.lowercased()
            if label == "g" || label == "oz" || label == "cup" || label == "tbsp" || label == "tsp" || label == "ml" {
                return "\(gramsText) \(label)"
            }
            
            // If serving label already includes a number (like "8 fl oz"), scale it
            if let firstChar = servingLabel.first, firstChar.isNumber {
                if quantity == 1.0 {
                    return servingLabel
                } else if let spaceIdx = servingLabel.firstIndex(of: " "),
                          let labelAmount = Double(servingLabel[servingLabel.startIndex..<spaceIdx]) {
                    // e.g. quantity=0.5, label="8 fl oz" → "4 fl oz"
                    let scaled = labelAmount * quantity
                    let unitPart = String(servingLabel[servingLabel.index(after: spaceIdx)...])
                    let scaledText = scaled.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(scaled))
                        : String(format: "%.4g", scaled)
                    return "\(scaledText) \(unitPart)"
                } else {
                    let q = quantity.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(quantity))
                        : String(format: "%.2g", quantity)
                    return "\(q) \(servingLabel)"
                }
            }
            
            // For custom portion names (like "cup", "bowl", "slice"), show with multiplier
            if quantity == 1.0 {
                return servingLabel
            } else {
                let q = quantity.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(quantity))
                    : String(format: "%.2g", quantity)
                return "\(q) \(servingLabel)"
            }
        }
        
        // No gram weight - fallback to simple quantity and serving
        if quantity == 1.0 {
            return servingLabel
        }

        // If label starts with a number (e.g., "8 fl oz"), scale it by quantity
        // so "0.5 × 8 fl oz" displays as "4 fl oz"
        if let firstChar = servingLabel.first, firstChar.isNumber,
           let spaceIdx = servingLabel.firstIndex(of: " "),
           let labelAmount = Double(servingLabel[servingLabel.startIndex..<spaceIdx]) {
            let scaled = labelAmount * quantity
            let unitPart = String(servingLabel[servingLabel.index(after: spaceIdx)...])
            let scaledText = scaled.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(scaled))
                : String(format: "%.4g", scaled)
            return "\(scaledText) \(unitPart)"
        }

        let q = quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(quantity))
            : String(format: "%.2g", quantity)
        return "\(q) \(servingLabel)"
    }
}

// MARK: - FoodLog Factory

extension FoodLog {
    /// Creates a FoodLog and freezes nutrition at creation time.
    /// This is the ONLY way a FoodLog should be created.
    static func create(
        mealType: MealType,
        quantity: Double,
        food: FoodItem,
        serving: ServingSize?,
        timestamp: Date = Date()
    ) -> FoodLog {
        let nutrition = NutritionCalculator.calculate(
            food: food,
            serving: serving,
            quantity: quantity
        )

        return FoodLog(
            timestamp: timestamp,
            mealType: mealType,
            quantity: quantity,
            foodItem: food,
            servingSize: serving,
            caloriesAtLogTime: nutrition.calories,
            proteinAtLogTime: nutrition.protein,
            carbsAtLogTime: nutrition.carbs,
            fatAtLogTime: nutrition.fat,
            fiberAtLogTime: nutrition.fiber,
            sodiumAtLogTime: nutrition.sodium,
            sugarAtLogTime: nutrition.sugar,
            saturatedFatAtLogTime: nutrition.saturatedFat,
            transFatAtLogTime: nutrition.transFat,
            monounsaturatedFatAtLogTime: nutrition.monounsaturatedFat,
            polyunsaturatedFatAtLogTime: nutrition.polyunsaturatedFat,
            cholesterolAtLogTime: nutrition.cholesterol,
            potassiumAtLogTime: nutrition.potassium,
            calciumAtLogTime: nutrition.calcium,
            ironAtLogTime: nutrition.iron,
            magnesiumAtLogTime: nutrition.magnesium,
            zincAtLogTime: nutrition.zinc,
            vitaminAAtLogTime: nutrition.vitaminA,
            vitaminCAtLogTime: nutrition.vitaminC,
            vitaminDAtLogTime: nutrition.vitaminD,
            vitaminEAtLogTime: nutrition.vitaminE,
            vitaminKAtLogTime: nutrition.vitaminK,
            vitaminB6AtLogTime: nutrition.vitaminB6,
            vitaminB12AtLogTime: nutrition.vitaminB12,
            folateAtLogTime: nutrition.folate,
            cholineAtLogTime: nutrition.choline,
            caffeineAtLogTime: nutrition.caffeine
        )
    }
}
