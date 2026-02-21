//
//  LoseItImporter.swift
//  BiteLedger
//
//  Created by Claude on 2/20/26.
//

import Foundation
import SwiftData

/// Service to import food logs from LoseIt CSV exports
struct LoseItImporter {

    struct ImportResult {
        let successCount: Int
        let failedCount: Int
        let errors: [String]
    }

    /// Parse a LoseIt CSV file and create FoodLog entries
    static func importCSV(from url: URL, modelContext: ModelContext) async throws -> ImportResult {
        let csvString = try String(contentsOf: url, encoding: .utf8)
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard lines.count > 1 else {
            throw ImportError.emptyFile
        }

        // Parse header
        let header = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let columnMap = parseHeader(header)

        var successCount = 0
        var failedCount = 0
        var errors: [String] = []
        var foodItemCache: [String: FoodItem] = [:]

        // Process each line
        for (index, line) in lines.dropFirst().enumerated() {
            let columns = parseCSVLine(line)

            do {
                let foodLog = try createFoodLog(from: columns, using: columnMap, modelContext: modelContext, foodItemCache: &foodItemCache)
                modelContext.insert(foodLog)
                successCount += 1

                // Batch save every 500 entries
                if successCount % 500 == 0 {
                    try modelContext.save()
                }
            } catch {
                failedCount += 1
                if errors.count < 100 {
                    let preview = line.prefix(100)
                    errors.append("Line \(index + 2): \(error.localizedDescription)\nData: \(preview)...")
                }
            }
        }

        // Final save
        try modelContext.save()

        return ImportResult(successCount: successCount, failedCount: failedCount, errors: errors)
    }

    private static func parseHeader(_ header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, column) in header.enumerated() {
            map[column.lowercased()] = index
        }
        return map
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn.trimmingCharacters(in: .whitespaces))
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        columns.append(currentColumn.trimmingCharacters(in: .whitespaces))
        return columns
    }

    private static func createFoodLog(from columns: [String], using columnMap: [String: Int], modelContext: ModelContext, foodItemCache: inout [String: FoodItem]) throws -> FoodLog {
        guard let dateStr = getValue(from: columns, columnMap: columnMap, key: "date") else {
            throw ImportError.missingRequiredField("date")
        }
        guard let name = getValue(from: columns, columnMap: columnMap, key: "name") else {
            throw ImportError.missingRequiredField("name")
        }
        guard let calories = getNumericValue(from: columns, columnMap: columnMap, key: "calories") else {
            throw ImportError.missingRequiredField("calories")
        }

        var date: Date?

        // Try time field first
        if let timeStr = getValue(from: columns, columnMap: columnMap, key: "time") {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            date = df.date(from: "\(dateStr) \(timeStr)")
        }

        // Try date formats
        if date == nil {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.calendar = Calendar(identifier: .gregorian)
            df.timeZone = TimeZone.current
            df.isLenient = false

            let formats: [(String, Bool)] = [
                ("M/d/yy", true),
                ("M/d/yyyy", false),
                ("MM/dd/yy", true),
                ("MM/dd/yyyy", false),
                ("yyyy-MM-dd", false)
            ]

            for (format, is2Digit) in formats {
                df.dateFormat = format
                if var parsed = df.date(from: dateStr) {
                    if is2Digit {
                        let cal = Calendar.current
                        let year = cal.component(.year, from: parsed)
                        if year < 100 {
                            var comp = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: parsed)
                            comp.year = 2000 + year
                            if let fixed = cal.date(from: comp) {
                                parsed = fixed
                            }
                        }
                    }
                    date = parsed
                    break
                }
            }
        }

        guard let timestamp = date else {
            throw ImportError.invalidDate(dateStr)
        }

        let typeStr = getValue(from: columns, columnMap: columnMap, key: "meal")
                   ?? getValue(from: columns, columnMap: columnMap, key: "type")
                   ?? "Snack"
        let mealType = parseMealType(typeStr)

        let protein = getNumericValue(from: columns, columnMap: columnMap, key: "protein (g)")
                   ?? getNumericValue(from: columns, columnMap: columnMap, key: "protein") ?? 0
        let carbs = getNumericValue(from: columns, columnMap: columnMap, key: "carbohydrates (g)")
                 ?? getNumericValue(from: columns, columnMap: columnMap, key: "carbohydrates")
                 ?? getNumericValue(from: columns, columnMap: columnMap, key: "carbs") ?? 0
        let fat = getNumericValue(from: columns, columnMap: columnMap, key: "fat (g)")
               ?? getNumericValue(from: columns, columnMap: columnMap, key: "fat") ?? 0
        let fiber = getNumericValue(from: columns, columnMap: columnMap, key: "fiber (g)")
                 ?? getNumericValue(from: columns, columnMap: columnMap, key: "fiber") ?? 0
        let sugar = getNumericValue(from: columns, columnMap: columnMap, key: "sugars (g)")
                 ?? getNumericValue(from: columns, columnMap: columnMap, key: "sugar") ?? 0
        let sodium = getNumericValue(from: columns, columnMap: columnMap, key: "sodium (mg)")
                  ?? getNumericValue(from: columns, columnMap: columnMap, key: "sodium") ?? 0
        let saturatedFat = getNumericValue(from: columns, columnMap: columnMap, key: "saturated fat (g)")
                        ?? getNumericValue(from: columns, columnMap: columnMap, key: "saturated fat") ?? 0
        let cholesterol = getNumericValue(from: columns, columnMap: columnMap, key: "cholesterol (mg)")
                       ?? getNumericValue(from: columns, columnMap: columnMap, key: "cholesterol") ?? 0

        let quantity = getValue(from: columns, columnMap: columnMap, key: "quantity") ?? "1"
        let units = getValue(from: columns, columnMap: columnMap, key: "units") ?? "serving"
        let amount = getValue(from: columns, columnMap: columnMap, key: "amount") ?? "\(quantity) \(units)"

        var totalGrams: Double = 100.0
        if let grams = getNumericValue(from: columns, columnMap: columnMap, key: "grams") {
            totalGrams = grams
        }

        let brand = getValue(from: columns, columnMap: columnMap, key: "brand")
        let cacheKey = "\(name)|\(brand ?? "")"

        let foodItem: FoodItem
        if let cached = foodItemCache[cacheKey] {
            foodItem = cached
        } else {
            let mult = totalGrams / 100.0
            let item = FoodItem(
                name: name,
                brand: brand,
                caloriesPer100g: mult > 0 ? calories / mult : calories,
                proteinPer100g: mult > 0 ? protein / mult : protein,
                carbsPer100g: mult > 0 ? carbs / mult : carbs,
                fatPer100g: mult > 0 ? fat / mult : fat,
                fiberPer100g: mult > 0 && fiber > 0 ? fiber / mult : nil,
                sugarPer100g: mult > 0 && sugar > 0 ? sugar / mult : nil,
                sodiumPer100g: mult > 0 && sodium > 0 ? (sodium / 1000) / mult : nil,
                saturatedFatPer100g: mult > 0 && saturatedFat > 0 ? saturatedFat / mult : nil,
                cholesterolPer100g: mult > 0 && cholesterol > 0 ? (cholesterol / 1000) / mult : nil,
                servingDescription: amount,
                gramsPerServing: totalGrams,
                source: "CSV Import"
            )
            modelContext.insert(item)
            foodItemCache[cacheKey] = item
            foodItem = item
        }

        return FoodLog(
            foodItem: foodItem,
            timestamp: timestamp,
            meal: mealType,
            servingMultiplier: 1.0,
            totalGrams: totalGrams
        )
    }

    private static func getValue(from columns: [String], columnMap: [String: Int], key: String) -> String? {
        guard let index = columnMap[key.lowercased()], index < columns.count else {
            return nil
        }
        let value = columns[index].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return value.isEmpty ? nil : value
    }

    private static func getNumericValue(from columns: [String], columnMap: [String: Int], key: String) -> Double? {
        guard let stringValue = getValue(from: columns, columnMap: columnMap, key: key) else {
            return nil
        }
        let cleanedValue = stringValue.replacingOccurrences(of: ",", with: "")
        return Double(cleanedValue)
    }

    private static func parseMealType(_ typeStr: String) -> MealType {
        let lower = typeStr.lowercased()
        if lower.contains("breakfast") {
            return .breakfast
        } else if lower.contains("lunch") {
            return .lunch
        } else if lower.contains("dinner") {
            return .dinner
        } else {
            return .snack
        }
    }

    enum ImportError: LocalizedError {
        case emptyFile
        case missingRequiredField(String)
        case invalidDate(String)

        var errorDescription: String? {
            switch self {
            case .emptyFile: return "The CSV file is empty"
            case .missingRequiredField(let field): return "Missing required field: \(field)"
            case .invalidDate(let dateStr): return "Invalid date format: \(dateStr)"
            }
        }
    }
}
