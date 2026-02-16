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
    
    // Optional micronutrients (can add later)
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var sodiumPer100g: Double?
    
    // Serving size information
    var servingDescription: String  // "1 cup" or "100g"
    var gramsPerServing: Double     // 240 or 100
    var servingSizeIsEstimated: Bool
    
    // Volume conversions (if available)
    var volumeConversionsData: Data?  // Encoded [VolumeConversion]
    
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
        servingDescription: String = "100g",
        gramsPerServing: Double = 100,
        servingSizeIsEstimated: Bool = true,
        source: String = "Manual"
    ) {
        self.id = UUID()
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.servingDescription = servingDescription
        self.gramsPerServing = gramsPerServing
        self.servingSizeIsEstimated = servingSizeIsEstimated
        self.dateAdded = Date()
        self.source = source
    }
}

// Helper for volume conversions
struct VolumeConversion: Codable {
    let unit: String  // "cup", "tbsp", etc
    let gramsPerUnit: Double
    let source: String  // "productLabel", "genericEstimate", "userDefined"
}