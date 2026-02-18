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
        
        // Join all lines for easier processing
        let fullText = lines.joined(separator: "\n").lowercased()
        
        print("🔍 Parsing nutrition label text:")
        print(fullText)
        print("---")
        
        // Check if this looks like a nutrition label
        guard fullText.contains("nutrition") || fullText.contains("calories") else {
            print("❌ Doesn't appear to be a nutrition label")
            return nil
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
            
            // Calories - most important field
            if let calories = extractCalories(from: line) {
                data.calories = calories
                foundAnyData = true
                print("✅ Found calories: \(calories)")
            }
            
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
