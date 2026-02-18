import Foundation

/// Common serving units with conversions to grams
enum ServingUnit: String, CaseIterable, Identifiable {
    // Volume
    case cup = "Cup"
    case fluidOunce = "Fluid Ounce"
    case tablespoon = "Tablespoon"
    case teaspoon = "Teaspoon"
    case milliliter = "Milliliter"
    case liter = "Liter"
    
    // Weight
    case gram = "Gram"
    case ounce = "Ounce"
    case pound = "Pound"
    
    // Product-specific
    case serving = "Serving"
    case container = "Container"
    
    var id: String { rawValue }
    
    var abbreviation: String {
        switch self {
        case .cup: return "cup"
        case .fluidOunce: return "fl oz"
        case .tablespoon: return "tbsp"
        case .teaspoon: return "tsp"
        case .milliliter: return "mL"
        case .liter: return "L"
        case .gram: return "g"
        case .ounce: return "oz"
        case .pound: return "lb"
        case .serving: return "serving"
        case .container: return "container"
        }
    }
    
    /// Convert this unit to grams (approximate for volume units)
    func toGrams(amount: Double, density: Double = 1.0) -> Double {
        switch self {
        // Volume units - use density (default 1.0 for water)
        case .cup:
            return amount * 236.588 * density // 1 cup ≈ 236.588 mL
        case .fluidOunce:
            return amount * 29.5735 * density // 1 fl oz ≈ 29.57 mL
        case .tablespoon:
            return amount * 14.7868 * density // 1 tbsp ≈ 14.79 mL
        case .teaspoon:
            return amount * 4.92892 * density // 1 tsp ≈ 4.93 mL
        case .milliliter:
            return amount * density
        case .liter:
            return amount * 1000 * density
            
        // Weight units
        case .gram:
            return amount
        case .ounce:
            return amount * 28.3495 // 1 oz = 28.35 g
        case .pound:
            return amount * 453.592 // 1 lb = 453.59 g
            
        // These need context
        case .serving, .container:
            return amount
        }
    }
    
    /// Get density for common food types
    static func densityFor(foodType: FoodType) -> Double {
        switch foodType {
        case .liquid: return 1.0
        case .peanutButter: return 1.08
        case .honey: return 1.42
        case .oil: return 0.92
        case .flour: return 0.59
        case .sugar: return 0.85
        case .milk: return 1.03
        case .other: return 1.0
        }
    }
}

enum FoodType {
    case liquid
    case peanutButter
    case honey
    case oil
    case flour
    case sugar
    case milk
    case other
    
    /// Infer food type from name/category
    static func infer(from name: String) -> FoodType {
        let lower = name.lowercased()
        if lower.contains("peanut butter") || lower.contains("almond butter") {
            return .peanutButter
        }
        if lower.contains("honey") {
            return .honey
        }
        if lower.contains("oil") {
            return .oil
        }
        if lower.contains("flour") {
            return .flour
        }
        if lower.contains("sugar") {
            return .sugar
        }
        if lower.contains("milk") || lower.contains("juice") {
            return .milk
        }
        if lower.contains("water") || lower.contains("beverage") || lower.contains("drink") {
            return .liquid
        }
        return .other
    }
}

/// Parse serving size from Open Food Facts format
struct ServingSizeParser {
    /// Parse "2 tbsp (32g)" or "1 cup" or "100g"
    static func parse(_ servingString: String?) -> (amount: Double, unit: ServingUnit, grams: Double?)? {
        guard let str = servingString?.lowercased() else {
            print("🔍 ServingSizeParser: servingString is nil")
            return nil
        }
        
        print("🔍 ServingSizeParser: parsing '\(str)'")
        
        // Extract the first number (the amount)
        let numberPattern = #"(\d+\.?\d*)"#
        guard let numberMatch = str.range(of: numberPattern, options: .regularExpression) else {
            print("⚠️ ServingSizeParser: no number found in '\(str)'")
            return nil
        }
        
        guard let amount = Double(str[numberMatch]) else {
            print("⚠️ ServingSizeParser: failed to convert '\(str[numberMatch])' to Double")
            return nil
        }
        
        print("🔍 ServingSizeParser: extracted amount = \(amount)")
        
        // Check for grams in parentheses like "(32g)" or "(33 g)"
        var gramsValue: Double? = nil
        if let gramsMatch = str.range(of: #"\((\d+\.?\d*)\s*g\)"#, options: .regularExpression) {
            // Extract just the number from the match
            let matchedStr = String(str[gramsMatch])
            if let gramsNumber = matchedStr.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
                gramsValue = Double(matchedStr[gramsNumber])
                print("🔍 ServingSizeParser: found grams in parentheses = \(gramsValue ?? 0)")
            }
        }
        
        // Split on parentheses to get the main part (before parentheses)
        let mainPart = str.components(separatedBy: "(").first ?? str
        
        // Detect unit from the main part (before parentheses)
        let unit: ServingUnit
        if mainPart.contains("cup") {
            unit = .cup
        } else if mainPart.contains("fl oz") || mainPart.contains("fluid ounce") {
            unit = .fluidOunce
        } else if mainPart.contains("tbsp") || mainPart.contains("tablespoon") || mainPart.contains("thsp") {
            // Handle common typo "thsp" as tablespoon
            unit = .tablespoon
        } else if mainPart.contains("tsp") || mainPart.contains("teaspoon") {
            unit = .teaspoon
        } else if mainPart.contains("ml") {
            unit = .milliliter
        } else if mainPart.contains("oz") && !mainPart.contains("fl") {
            unit = .ounce
        } else if mainPart.contains("lb") || mainPart.contains("pound") {
            unit = .pound
        } else if mainPart.contains("serving") || mainPart.contains("portion") {
            // If it says "serving" or "portion", use the .serving unit
            unit = .serving
        } else if mainPart.trimmingCharacters(in: .whitespaces).hasSuffix("g") {
            // Only treat as grams if the main part ends with 'g' (like "100g")
            unit = .gram
            gramsValue = amount
        } else {
            // Default to serving if we can't determine the unit
            unit = .serving
        }
        
        print("🔍 ServingSizeParser: detected unit = \(unit.rawValue)")
        print("✅ ServingSizeParser: result = (\(amount) \(unit.rawValue), \(gramsValue ?? 0)g)")
        
        return (amount, unit, gramsValue)
    }
}
