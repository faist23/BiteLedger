//
//  FoodLog.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//


import SwiftData
import Foundation

@Model
final class FoodLog {
    var id: UUID
    var foodItem: FoodItem?  // Optional in case food gets deleted
    var timestamp: Date
    var meal: MealType
    
    // What the user logged
    var servingMultiplier: Double  // 1.5 (ate 1.5 servings)
    var totalGrams: Double  // calculated: 1.5 × 240g = 360g
    var selectedPortionId: Int?  // ID of selected USDA portion (if applicable)
    var displayUnit: String?  // The unit to display (e.g., "g", "oz") - overrides automatic unit detection
    
    // Cached nutrition (for performance - calculated at log time)
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    
    // Optional: user notes
    var notes: String?
    
    init(
        foodItem: FoodItem,
        timestamp: Date = Date(),
        meal: MealType,
        servingMultiplier: Double,
        totalGrams: Double,
        selectedPortionId: Int? = nil
    ) {
        self.id = UUID()
        self.foodItem = foodItem
        self.timestamp = timestamp
        self.meal = meal
        self.servingMultiplier = servingMultiplier
        self.totalGrams = totalGrams
        self.selectedPortionId = selectedPortionId
        
        // Calculate and cache nutrition
        let multiplier = totalGrams / 100.0
        self.calories = foodItem.caloriesPer100g * multiplier
        self.protein = foodItem.proteinPer100g * multiplier
        self.carbs = foodItem.carbsPer100g * multiplier
        self.fat = foodItem.fatPer100g * multiplier
    }
    
    /// Format the serving display text (e.g., "2 tbsp" or "1.5 cups" or "1 medium")
    var servingDisplayText: String {
        guard let foodItem = foodItem else {
            return String(format: "%.0fg", totalGrams)
        }
        
        // If displayUnit is explicitly set (e.g., user switched to grams), use it
        if let displayUnit = displayUnit {
            if displayUnit == "g" {
                // Show grams directly
                return String(format: "%.0fg", totalGrams)
            } else if displayUnit == "oz" {
                // Show ounces
                let ounces = totalGrams / 28.3495
                if ounces.truncatingRemainder(dividingBy: 1) == 0 {
                    return "\(Int(ounces)) oz"
                } else {
                    return String(format: "%.1f oz", ounces)
                }
            }
            // Other units can be added here as needed
        }
        
        // If a portion is selected, show it (e.g., "1 medium" or "2 large")
        if let portionId = selectedPortionId,
           let portions = foodItem.portions,
           let portion = portions.first(where: { $0.id == portionId }) {
            if servingMultiplier.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(servingMultiplier)) \(portion.modifier)"
            } else {
                return String(format: "%.1f %@", servingMultiplier, portion.modifier)
            }
        }
        
        // Extract just the unit from servingDescription (e.g., "15.97tbsp" -> "tbsp")
        let description = foodItem.servingDescription
        
        // Try to extract unit abbreviation (non-numeric characters)
        let unit = description.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))).joined()
        
        if !unit.isEmpty {
            // Format: "2 tbsp" or "1.5 cups"
            if servingMultiplier.truncatingRemainder(dividingBy: 1) == 0 {
                // Whole number
                return "\(Int(servingMultiplier)) \(unit)"
            } else {
                // Decimal
                return String(format: "%.1f %@", servingMultiplier, unit)
            }
        }
        
        // Fallback to showing grams
        return String(format: "%.0fg", totalGrams)
    }
    
    /// Convenience initializer with servings
    convenience init(
        foodItem: FoodItem,
        servings: Double,
        mealType: MealType,
        timestamp: Date = Date(),
        selectedPortionId: Int? = nil
    ) {
        let totalGrams = foodItem.gramsPerServing * servings
        self.init(
            foodItem: foodItem,
            timestamp: timestamp,
            meal: mealType,
            servingMultiplier: servings,
            totalGrams: totalGrams,
            selectedPortionId: selectedPortionId
        )
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }
}