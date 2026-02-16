//
//  NutritionFacts.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//


import Foundation

struct NutritionFacts: Codable {
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var sodiumPer100g: Double?
}