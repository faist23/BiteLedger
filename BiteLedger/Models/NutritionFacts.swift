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
}