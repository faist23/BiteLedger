//
//  FoodItem.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftData
import Foundation

// MARK: - NutritionMode

enum NutritionMode: String, Codable {
    /// Nutrition values stored per 100g. Used for packaged foods, USDA whole foods.
    /// ServingSizes must have gramWeight to calculate correctly.
    case per100g

    /// Nutrition values stored per 1 default serving. Used for manual entry,
    /// recipes, FatSecret no-gram items, and LoseIt imports.
    case perServing
}

// MARK: - MealType

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snack     = "Snack"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch:     return "sun.max"
        case .dinner:    return "moon"
        case .snack:     return "leaf"
        }
    }
}

// MARK: - FoodItem

@Model
final class FoodItem {

    // MARK: Identity
    var id: UUID
    var name: String
    var brand: String?
    var barcode: String?

    /// Where this food came from.
    /// Values: "OpenFoodFacts" | "USDA" | "FatSecret" | "Manual Entry" | "CSV Import"
    var source: String

    var dateAdded: Date

    // MARK: Nutrition Mode
    /// Determines how nutrition values are interpreted.
    /// .per100g  → calories/protein/etc are per 100 grams
    /// .perServing → calories/protein/etc are per 1 default serving
    var nutritionMode: NutritionMode

    // MARK: Nutrition Values
    // Interpretation depends on nutritionMode (see above).
    // All values use standard units:
    //   calories → kcal
    //   protein, carbs, fat, fiber, sugar, saturatedFat, transFat → grams
    //   sodium, cholesterol, potassium, calcium, iron → milligrams
    //   vitaminA, vitaminC, vitaminD, vitaminB6, vitaminB12, folate → micrograms or mg per label convention
    //   caffeine → milligrams

    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    // Optional macros
    var fiber: Double?
    var sugar: Double?
    var saturatedFat: Double?
    var transFat: Double?
    var polyunsaturatedFat: Double?
    var monounsaturatedFat: Double?

    // Optional minerals (mg)
    var sodium: Double?
    var cholesterol: Double?
    var potassium: Double?
    var calcium: Double?
    var iron: Double?
    var magnesium: Double?
    var zinc: Double?

    // Optional vitamins
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var vitaminE: Double?
    var vitaminK: Double?
    var vitaminB6: Double?
    var vitaminB12: Double?
    var folate: Double?
    var choline: Double?

    // Optional other
    var caffeine: Double?

    // MARK: Relationships
    @Relationship(deleteRule: .cascade) var servingSizes: [ServingSize] = []
    @Relationship(deleteRule: .nullify) var foodLogs: [FoodLog] = []

    // MARK: Init
    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        source: String,
        dateAdded: Date = Date(),
        nutritionMode: NutritionMode,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        sugar: Double? = nil,
        saturatedFat: Double? = nil,
        transFat: Double? = nil,
        polyunsaturatedFat: Double? = nil,
        monounsaturatedFat: Double? = nil,
        sodium: Double? = nil,
        cholesterol: Double? = nil,
        potassium: Double? = nil,
        calcium: Double? = nil,
        iron: Double? = nil,
        magnesium: Double? = nil,
        zinc: Double? = nil,
        vitaminA: Double? = nil,
        vitaminC: Double? = nil,
        vitaminD: Double? = nil,
        vitaminE: Double? = nil,
        vitaminK: Double? = nil,
        vitaminB6: Double? = nil,
        vitaminB12: Double? = nil,
        folate: Double? = nil,
        choline: Double? = nil,
        caffeine: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.source = source
        self.dateAdded = dateAdded
        self.nutritionMode = nutritionMode
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.saturatedFat = saturatedFat
        self.transFat = transFat
        self.polyunsaturatedFat = polyunsaturatedFat
        self.monounsaturatedFat = monounsaturatedFat
        self.sodium = sodium
        self.cholesterol = cholesterol
        self.potassium = potassium
        self.calcium = calcium
        self.iron = iron
        self.magnesium = magnesium
        self.zinc = zinc
        self.vitaminA = vitaminA
        self.vitaminC = vitaminC
        self.vitaminD = vitaminD
        self.vitaminE = vitaminE
        self.vitaminK = vitaminK
        self.vitaminB6 = vitaminB6
        self.vitaminB12 = vitaminB12
        self.folate = folate
        self.choline = choline
        self.caffeine = caffeine
    }

    // MARK: Computed Helpers

    /// The default serving size for display in pickers and search results.
    var defaultServing: ServingSize? {
        servingSizes.first(where: { $0.isDefault })
            ?? servingSizes.min(by: { $0.sortOrder < $1.sortOrder })
    }

    /// Display name including brand if available.
    var displayName: String {
        if let brand, !brand.isEmpty {
            return "\(name) · \(brand)"
        }
        return name
    }
}
