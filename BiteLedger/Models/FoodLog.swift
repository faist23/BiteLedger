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
        totalGrams: Double
    ) {
        self.id = UUID()
        self.foodItem = foodItem
        self.timestamp = timestamp
        self.meal = meal
        self.servingMultiplier = servingMultiplier
        self.totalGrams = totalGrams
        
        // Calculate and cache nutrition
        let multiplier = totalGrams / 100.0
        self.calories = foodItem.caloriesPer100g * multiplier
        self.protein = foodItem.proteinPer100g * multiplier
        self.carbs = foodItem.carbsPer100g * multiplier
        self.fat = foodItem.fatPer100g * multiplier
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }
}