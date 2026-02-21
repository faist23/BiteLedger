//
//  FoodItem.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//


import SwiftData
import Foundation

@Model
final class FoodItem {
    var id: UUID
    var barcode: String?
    var name: String
    var brand: String?
    
    // Nutrition per 100g (always stored this way for consistency)
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    
    // Optional micronutrients
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var sodiumPer100g: Double?
    var saturatedFatPer100g: Double?
    var transFatPer100g: Double?
    var monounsaturatedFatPer100g: Double?
    var polyunsaturatedFatPer100g: Double?
    var cholesterolPer100g: Double?
    
    // Vitamins and minerals
    var vitaminAPer100g: Double?
    var vitaminCPer100g: Double?
    var vitaminDPer100g: Double?
    var calciumPer100g: Double?
    var ironPer100g: Double?
    var potassiumPer100g: Double?
    
    // Serving size information
    var servingDescription: String  // "1 cup" or "100g"
    var gramsPerServing: Double     // 240 or 100
    var servingSizeIsEstimated: Bool
    
    // Volume conversions (if available)
    var volumeConversionsData: Data?  // Encoded [VolumeConversion]
    
    // USDA portion sizes (if available)
    var portionsData: Data?  // Encoded [StoredPortion]
    
    // Metadata
    var dateAdded: Date
    var source: String  // "OpenFoodFacts", "USDA", "Manual"
    var imageURL: String?
    
    init(
        barcode: String? = nil,
        name: String,
        brand: String? = nil,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        fiberPer100g: Double? = nil,
        sugarPer100g: Double? = nil,
        sodiumPer100g: Double? = nil,
        saturatedFatPer100g: Double? = nil,
        transFatPer100g: Double? = nil,
        monounsaturatedFatPer100g: Double? = nil,
        polyunsaturatedFatPer100g: Double? = nil,
        cholesterolPer100g: Double? = nil,
        vitaminAPer100g: Double? = nil,
        vitaminCPer100g: Double? = nil,
        vitaminDPer100g: Double? = nil,
        calciumPer100g: Double? = nil,
        ironPer100g: Double? = nil,
        potassiumPer100g: Double? = nil,
        servingDescription: String = "100g",
        gramsPerServing: Double = 100,
        servingSizeIsEstimated: Bool = true,
        source: String = "Manual",
        imageURL: String? = nil
    ) {
        self.id = UUID()
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sugarPer100g = sugarPer100g
        self.sodiumPer100g = sodiumPer100g
        self.saturatedFatPer100g = saturatedFatPer100g
        self.transFatPer100g = transFatPer100g
        self.monounsaturatedFatPer100g = monounsaturatedFatPer100g
        self.polyunsaturatedFatPer100g = polyunsaturatedFatPer100g
        self.cholesterolPer100g = cholesterolPer100g
        self.vitaminAPer100g = vitaminAPer100g
        self.vitaminCPer100g = vitaminCPer100g
        self.vitaminDPer100g = vitaminDPer100g
        self.calciumPer100g = calciumPer100g
        self.ironPer100g = ironPer100g
        self.potassiumPer100g = potassiumPer100g
        self.servingDescription = servingDescription
        self.gramsPerServing = gramsPerServing
        self.servingSizeIsEstimated = servingSizeIsEstimated
        self.dateAdded = Date()
        self.source = source
        self.imageURL = imageURL
    }
    
    /// Convenience initializer from NutritionFacts
    convenience init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        nutritionPer100g: NutritionFacts,
        servingSize: Double = 100,
        servingSizeUnit: String = "g",
        source: String = "OpenFoodFacts",
        imageURL: String? = nil
    ) {
        self.init(
            barcode: barcode,
            name: name,
            brand: brand,
            caloriesPer100g: nutritionPer100g.caloriesPer100g,
            proteinPer100g: nutritionPer100g.proteinPer100g,
            carbsPer100g: nutritionPer100g.carbsPer100g,
            fatPer100g: nutritionPer100g.fatPer100g,
            fiberPer100g: nutritionPer100g.fiberPer100g,
            sugarPer100g: nutritionPer100g.sugarPer100g,
            sodiumPer100g: nutritionPer100g.sodiumPer100g,
            saturatedFatPer100g: nutritionPer100g.saturatedFatPer100g,
            transFatPer100g: nutritionPer100g.transFatPer100g,
            monounsaturatedFatPer100g: nutritionPer100g.monounsaturatedFatPer100g,
            polyunsaturatedFatPer100g: nutritionPer100g.polyunsaturatedFatPer100g,
            cholesterolPer100g: nutritionPer100g.cholesterolPer100g,
            vitaminAPer100g: nutritionPer100g.vitaminAPer100g,
            vitaminCPer100g: nutritionPer100g.vitaminCPer100g,
            vitaminDPer100g: nutritionPer100g.vitaminDPer100g,
            calciumPer100g: nutritionPer100g.calciumPer100g,
            ironPer100g: nutritionPer100g.ironPer100g,
            potassiumPer100g: nutritionPer100g.potassiumPer100g,
            servingDescription: "\(servingSize)\(servingSizeUnit)",
            gramsPerServing: servingSize,
            servingSizeIsEstimated: false,
            source: source,
            imageURL: imageURL
        )
    }
}

// Helper for volume conversions
struct VolumeConversion: Codable {
    let unit: String  // "cup", "tbsp", etc
    let gramsPerUnit: Double
    let source: String  // "productLabel", "genericEstimate", "userDefined"
}

// Helper for storing USDA portions
struct StoredPortion: Codable, Identifiable, Hashable {
    let id: Int
    let amount: Double
    let modifier: String
    let gramWeight: Double
    
    var displayName: String {
        if amount == 1.0 {
            return modifier
        }
        return "\(amount) \(modifier)"
    }
}

// Extension to work with portions
extension FoodItem {
    var portions: [StoredPortion]? {
        get {
            guard let data = portionsData else { return nil }
            return try? JSONDecoder().decode([StoredPortion].self, from: data)
        }
        set {
            portionsData = try? JSONEncoder().encode(newValue)
        }
    }
}