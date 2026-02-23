//
//  DataExporter.swift
//  BiteLedger
//
//  Created by Claude on 2/20/26.
//

import Foundation
import SwiftData

/// Service to export food logs to CSV format
struct DataExporter {
    
    /// Export all food logs to CSV format
    static func exportToCSV(logs: [FoodLog]) throws -> URL {
        // Create CSV header - comprehensive nutrient export
        var csvString = "Date,Time,Meal,Name,Brand,Amount,Grams,Calories,Protein,Carbs,Fat,Fiber,Sugar,Sodium,Saturated Fat,Trans Fat,Monounsaturated Fat,Polyunsaturated Fat,Cholesterol,Vitamin A,Vitamin C,Vitamin D,Vitamin E,Vitamin K,Vitamin B6,Vitamin B12,Folate,Choline,Calcium,Iron,Potassium,Magnesium,Zinc,Caffeine\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        // Sort logs by date
        let sortedLogs = logs.sorted { $0.timestamp < $1.timestamp }
        
        // Add each log as a row
        for log in sortedLogs {
            guard let foodItem = log.foodItem else { continue }
            
            let date = dateFormatter.string(from: log.timestamp)
            let time = timeFormatter.string(from: log.timestamp)
            let meal = log.meal.rawValue
            let name = escapeCSV(foodItem.name)
            let brand = escapeCSV(foodItem.brand ?? "")
            let amount = escapeCSV(log.servingDisplayText)
            let grams = String(format: "%.1f", log.totalGrams)
            let calories = String(format: "%.0f", log.calories)
            let protein = String(format: "%.1f", log.protein)
            let carbs = String(format: "%.1f", log.carbs)
            let fat = String(format: "%.1f", log.fat)
            
            // Calculate all nutrients based on grams
            let multiplier = log.totalGrams / 100.0
            
            // Macronutrients (in grams)
            let fiber = String(format: "%.1f", (foodItem.fiberPer100g ?? 0) * multiplier)
            let sugar = String(format: "%.1f", (foodItem.sugarPer100g ?? 0) * multiplier)
            let saturatedFat = String(format: "%.1f", (foodItem.saturatedFatPer100g ?? 0) * multiplier)
            let transFat = String(format: "%.1f", (foodItem.transFatPer100g ?? 0) * multiplier)
            let monounsaturatedFat = String(format: "%.1f", (foodItem.monounsaturatedFatPer100g ?? 0) * multiplier)
            let polyunsaturatedFat = String(format: "%.1f", (foodItem.polyunsaturatedFatPer100g ?? 0) * multiplier)
            
            // Nutrients in mg (convert from grams)
            let sodium = String(format: "%.1f", (foodItem.sodiumPer100g ?? 0) * 1000 * multiplier)
            let cholesterol = String(format: "%.1f", (foodItem.cholesterolPer100g ?? 0) * 1000 * multiplier)
            let vitaminC = String(format: "%.1f", (foodItem.vitaminCPer100g ?? 0) * 1000 * multiplier)
            let vitaminE = String(format: "%.1f", (foodItem.vitaminEPer100g ?? 0) * 1000 * multiplier)
            let vitaminB6 = String(format: "%.1f", (foodItem.vitaminB6Per100g ?? 0) * 1000 * multiplier)
            let choline = String(format: "%.1f", (foodItem.cholinePer100g ?? 0) * 1000 * multiplier)
            let calcium = String(format: "%.1f", (foodItem.calciumPer100g ?? 0) * 1000 * multiplier)
            let iron = String(format: "%.1f", (foodItem.ironPer100g ?? 0) * 1000 * multiplier)
            let potassium = String(format: "%.1f", (foodItem.potassiumPer100g ?? 0) * 1000 * multiplier)
            let magnesium = String(format: "%.1f", (foodItem.magnesiumPer100g ?? 0) * 1000 * multiplier)
            let zinc = String(format: "%.1f", (foodItem.zincPer100g ?? 0) * 1000 * multiplier)
            let caffeine = String(format: "%.1f", (foodItem.caffeinePer100g ?? 0) * 1000 * multiplier)
            
            // Nutrients in mcg (convert from grams)
            let vitaminA = String(format: "%.1f", (foodItem.vitaminAPer100g ?? 0) * 1_000_000 * multiplier)
            let vitaminD = String(format: "%.1f", (foodItem.vitaminDPer100g ?? 0) * 1_000_000 * multiplier)
            let vitaminK = String(format: "%.1f", (foodItem.vitaminKPer100g ?? 0) * 1_000_000 * multiplier)
            let vitaminB12 = String(format: "%.1f", (foodItem.vitaminB12Per100g ?? 0) * 1_000_000 * multiplier)
            let folate = String(format: "%.1f", (foodItem.folatePer100g ?? 0) * 1_000_000 * multiplier)
            
            let row = "\(date),\(time),\(meal),\(name),\(brand),\(amount),\(grams),\(calories),\(protein),\(carbs),\(fat),\(fiber),\(sugar),\(sodium),\(saturatedFat),\(transFat),\(monounsaturatedFat),\(polyunsaturatedFat),\(cholesterol),\(vitaminA),\(vitaminC),\(vitaminD),\(vitaminE),\(vitaminK),\(vitaminB6),\(vitaminB12),\(folate),\(choline),\(calcium),\(iron),\(potassium),\(magnesium),\(zinc),\(caffeine)\n"
            csvString.append(row)
        }
        
        // Write to temporary file
        let fileName = "BiteLedger_Export_\(dateFormatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    /// Export logs for a specific date range
    static func exportToCSV(logs: [FoodLog], startDate: Date, endDate: Date) throws -> URL {
        let filteredLogs = logs.filter { log in
            log.timestamp >= startDate && log.timestamp <= endDate
        }
        return try exportToCSV(logs: filteredLogs)
    }
    
    /// Escape special characters for CSV
    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return string
    }
}
