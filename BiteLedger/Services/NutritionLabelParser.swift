import Foundation

/// Parsed nutrition data from a label scan
struct NutritionData {
    var servingSize: String?
    var servingsPerContainer: String?
    var calories: Double?
    var totalFat: Double?
    var saturatedFat: Double?
    var transFat: Double?
    var cholesterol: Double?
    var sodium: Double?
    var totalCarbs: Double?
    var fiber: Double?
    var sugars: Double?
    var addedSugars: Double?
    var protein: Double?
    var vitaminD: Double?
    var calcium: Double?
    var iron: Double?
    var potassium: Double?
}

/// Parser for extracting nutrition information from OCR text
struct NutritionLabelParser {
    
    /// Parse an array of text lines from OCR into nutrition data
    static func parse(_ lines: [String]) -> NutritionData? {
        var data = NutritionData()
        var foundAnyData = false
        
        print("🔍 Parsing nutrition label text (\(lines.count) lines):")
        for (index, line) in lines.enumerated() {
            print("Line \(index): \"\(line)\"")
        }
        print("---")
        
        // Join all lines for easier processing
        let fullText = lines.joined(separator: " ").lowercased()
        
        // Check if this looks like a nutrition label
        guard fullText.contains("nutrition") || fullText.contains("calories") else {
            print("❌ Doesn't appear to be a nutrition label")
            return nil
        }
        
        // Try to find calories in the full text first (handles multi-line cases)
        if let calories = extractCaloriesFromFullText(lines) {
            data.calories = calories
            foundAnyData = true
            print("✅ Found calories from full text: \(calories)")
        }
        
        // Parse each line
        for line in lines {
            let cleaned = line.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Serving size
            if cleaned.contains("serving size") {
                data.servingSize = extractServingSize(from: line)
                foundAnyData = true
            }
            
            // Servings per container
            if cleaned.contains("servings per container") {
                data.servingsPerContainer = extractNumber(from: line)
                foundAnyData = true
            }
            
            // Skip calorie extraction from individual lines since we already did it from full text
            // (This prevents false positives from line-by-line parsing)
            
            // Total Fat
            if let fat = extractNutrient(from: line, patterns: ["total fat", "fat"]) {
                data.totalFat = fat
                foundAnyData = true
                print("✅ Found total fat: \(fat)g")
            }
            
            // Saturated Fat
            if let satFat = extractNutrient(from: line, patterns: ["saturated fat", "sat. fat", "sat fat"]) {
                data.saturatedFat = satFat
                foundAnyData = true
            }
            
            // Trans Fat
            if let transFat = extractNutrient(from: line, patterns: ["trans fat"]) {
                data.transFat = transFat
                foundAnyData = true
            }
            
            // Cholesterol
            if let cholesterol = extractNutrient(from: line, patterns: ["cholesterol"]) {
                data.cholesterol = cholesterol
                foundAnyData = true
            }
            
            // Sodium
            if let sodium = extractNutrient(from: line, patterns: ["sodium"]) {
                data.sodium = sodium
                foundAnyData = true
                print("✅ Found sodium: \(sodium)mg")
            }
            
            // Total Carbohydrates
            if let carbs = extractNutrient(from: line, patterns: ["total carbohydrate", "total carb", "carbohydrate"]) {
                data.totalCarbs = carbs
                foundAnyData = true
                print("✅ Found carbs: \(carbs)g")
            }
            
            // Dietary Fiber
            if let fiber = extractNutrient(from: line, patterns: ["dietary fiber", "fiber"]) {
                data.fiber = fiber
                foundAnyData = true
            }
            
            // Total Sugars
            if let sugars = extractNutrient(from: line, patterns: ["total sugars", "sugars"]) {
                data.sugars = sugars
                foundAnyData = true
            }
            
            // Added Sugars
            if let addedSugars = extractNutrient(from: line, patterns: ["added sugars", "incl. added sugars"]) {
                data.addedSugars = addedSugars
                foundAnyData = true
            }
            
            // Protein
            if let protein = extractNutrient(from: line, patterns: ["protein"]) {
                data.protein = protein
                foundAnyData = true
                print("✅ Found protein: \(protein)g")
            }
            
            // Vitamin D
            if let vitaminD = extractNutrient(from: line, patterns: ["vitamin d"]) {
                data.vitaminD = vitaminD
                foundAnyData = true
            }
            
            // Calcium
            if let calcium = extractNutrient(from: line, patterns: ["calcium"]) {
                data.calcium = calcium
                foundAnyData = true
            }
            
            // Iron
            if let iron = extractNutrient(from: line, patterns: ["iron"]) {
                data.iron = iron
                foundAnyData = true
            }
            
            // Potassium
            if let potassium = extractNutrient(from: line, patterns: ["potassium"]) {
                data.potassium = potassium
                foundAnyData = true
            }
        }
        
        return foundAnyData ? data : nil
    }
    
    // MARK: - Helper Methods
    
    private static func extractServingSize(from text: String) -> String? {
        // Look for patterns like "Serving size 2/3 cup (55g)" or "1 cup (240ml)"
        let pattern = #"serving size\s*(.+?)(?:\n|$)"#
        if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let extracted = String(text[match])
                .replacingOccurrences(of: "serving size", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return extracted.isEmpty ? nil : extracted
        }
        return nil
    }
    
    private static func extractNumber(from text: String) -> String? {
        // Extract first number from text
        let pattern = #"\d+"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return String(text[match])
        }
        return nil
    }
    
    private static func extractCaloriesFromFullText(_ lines: [String]) -> Double? {
        // Look for "Calories" line and check surrounding lines for the number
        // Prioritize lines that appear to be from the actual nutrition facts table
        for (index, line) in lines.enumerated() {
            let cleaned = line.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Found a line containing "calories"
            if cleaned.contains("calories") || cleaned.contains("calorie") {
                print("📍 Found calories keyword at line \(index): \"\(line)\"")
                
                // Skip marketing/promotional text (these patterns indicate it's not the nutrition facts)
                if cleaned.contains("fewer calories") || 
                   cleaned.contains("reduced") ||
                   cleaned.contains("than") ||
                   cleaned.contains("%") ||
                   cleaned.contains("percent") {
                    print("⚠️ Skipping marketing text at line \(index)")
                    continue
                }
                
                // Look for "Amount per serving" nearby (indicates this is the nutrition facts section)
                let isNearAmountPerServing = (index > 0 && lines[index - 1].lowercased().contains("amount per serving")) ||
                                             (index > 1 && lines[index - 2].lowercased().contains("amount per serving"))
                
                // If this is just "Calories" on its own line (FDA format), check next line
                if cleaned == "calories" || cleaned == "calorie" {
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1]
                        print("📍 Checking next line for standalone 'Calories': \"\(nextLine)\"")
                        
                        // Check if next line is just a number
                        if let numberMatch = nextLine.range(of: #"^\s*\d+\s*$"#, options: .regularExpression) {
                            let numberStr = String(nextLine[numberMatch]).trimmingCharacters(in: .whitespaces)
                            if let value = Double(numberStr), value > 0 && value < 1000 {
                                print("✅ Found calories on next line (FDA format): \(value)")
                                return value
                            }
                        }
                        
                        // Special case: If next line is "Total Fat" or "% Daily Value",
                        // the calorie number was likely missed by OCR
                        // Check if we can find it in nearby marketing text
                        if nextLine.lowercased().contains("total fat") || 
                           nextLine.lowercased().contains("daily value") ||
                           nextLine.lowercased().contains("% daily") {
                            print("⚠️ Calorie number appears to be missing between 'Calories' and '\(nextLine)'")
                            print("⚠️ Will try to find it in surrounding text...")
                            
                            // Look backwards in earlier lines for calorie references
                            for backIndex in stride(from: index - 1, through: max(0, index - 10), by: -1) {
                                let backLine = lines[backIndex].lowercased()
                                if backLine.contains("calorie") && backLine.contains("per") {
                                    print("📍 Found potential calorie reference: '\(lines[backIndex])'")
                                    // Extract number from patterns like "5 calories per serving"
                                    // Extract all numbers from the line
                                    let allMatches = lines[backIndex].matches(of: /\d+/)
                                    let numbers = allMatches.map { Int($0.output) ?? 0 }
                                    if let firstValid = numbers.first(where: { $0 > 0 && $0 < 1000 }) {
                                        print("✅ Found calories from reference text: \(firstValid)")
                                        return Double(firstValid)
                                    }
                                }
                            }
                        }
                    }
                    continue
                }
                
                // Strategy 1: Number on same line after "calories" (e.g., "Calories 230")
                // But only if it looks like nutrition facts format
                if isNearAmountPerServing || cleaned.starts(with: "calories") {
                    if let numberMatch = line.range(of: #"calories\s*(\d+)"#, options: [.regularExpression, .caseInsensitive]) {
                        let matchText = String(line[numberMatch])
                        if let numMatch = matchText.range(of: #"\d+"#, options: .regularExpression) {
                            let numberStr = String(matchText[numMatch])
                            if let value = Double(numberStr), value > 0 && value < 1000 {
                                print("✅ Found calories on same line: \(value)")
                                return value
                            }
                        }
                    }
                }
                
                // Strategy 2: Number on next line (common in FDA labels)
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    print("📍 Checking next line: \"\(nextLine)\"")
                    // Only match if next line is JUST a number
                    if let numberMatch = nextLine.range(of: #"^\s*\d+\s*$"#, options: .regularExpression) {
                        let numberStr = String(nextLine[numberMatch]).trimmingCharacters(in: .whitespaces)
                        if let value = Double(numberStr), value > 0 && value < 1000 {
                            print("✅ Found calories on next line: \(value)")
                            return value
                        }
                    }
                }
            }
        }
        
        // Fallback: Look for "X calories per serving" pattern in marketing text
        // This catches cases like "5 CALORIES PER TWO PIECE SERVING"
        print("⚠️ Standard calorie detection failed, trying fallback patterns...")
        for (index, line) in lines.enumerated() {
            let cleaned = line.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Pattern: "5 calories per serving" or "reduced from 8 to 5 calories"
            if cleaned.contains("calories per") || (cleaned.contains("to") && cleaned.contains("calories")) {
                print("📍 Found calorie reference at line \(index): \"\(line)\"")
                
                // Extract all numbers from the line
                let numbers = line.matches(of: /\d+/).map { Int($0.output) ?? 0 }
                print("📍 Numbers found in line: \(numbers)")
                
                // For "reduced from X to Y" pattern, take the last (newer) value
                // For "Y calories per serving", take the first reasonable value
                for number in numbers.reversed() {
                    if number > 0 && number < 1000 {
                        print("✅ Found calories from fallback pattern: \(number)")
                        return Double(number)
                    }
                }
            }
        }
        
        print("❌ Could not find calories value")
        return nil
    }
    
    private static func extractCalories(from text: String) -> Double? {
        let cleaned = text.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Pattern: "Calories 230" or "230 Calories" or "Amount per serving\nCalories 230"
        if cleaned.contains("calories") {
            // Look for number near "calories"
            let patterns = [
                #"calories\s*(\d+)"#,
                #"(\d+)\s*calories"#,
                #"amount per serving\s*calories\s*(\d+)"#
            ]
            
            for pattern in patterns {
                if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    let matchText = String(text[match])
                    // Extract just the number
                    if let numberMatch = matchText.range(of: #"\d+"#, options: .regularExpression) {
                        let numberStr = String(matchText[numberMatch])
                        return Double(numberStr)
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func extractNutrient(from text: String, patterns: [String]) -> Double? {
        let cleaned = text.lowercased().trimmingCharacters(in: .whitespaces)
        
        for pattern in patterns {
            if cleaned.contains(pattern) {
                // Look for number followed by g, mg, mcg, or µg
                let numberPatterns = [
                    #"(\d+\.?\d*)\s*g"#,      // "8g" or "8 g"
                    #"(\d+\.?\d*)\s*mg"#,     // "160mg"
                    #"(\d+\.?\d*)\s*mcg"#,    // "2mcg"
                    #"(\d+\.?\d*)\s*µg"#,     // "2µg"
                    #"(\d+\.?\d*)\s*(?=\s|$)"# // Just number
                ]
                
                for numPattern in numberPatterns {
                    if let match = text.range(of: numPattern, options: .regularExpression) {
                        let matchText = String(text[match])
                        // Extract just the number part
                        if let numberMatch = matchText.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
                            let numberStr = String(matchText[numberMatch])
                            if let value = Double(numberStr) {
                                // Convert based on unit
                                if matchText.contains("mg") {
                                    return value // Keep as mg
                                } else if matchText.contains("mcg") || matchText.contains("µg") {
                                    return value // Keep as mcg/µg
                                } else {
                                    return value // Assume grams
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
}
