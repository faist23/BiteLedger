import Foundation

// MARK: - USDA FoodData Central Service

/// Service for interacting with the USDA FoodData Central API
/// Great for whole foods, fruits, vegetables, and basic ingredients
@MainActor
class USDAFoodDataService {
    static let shared = USDAFoodDataService()
    
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    private let session: URLSession
    
    // API key - replace with your USDA FoodData Central API key
    // Get your free API key at: https://fdc.nal.usda.gov/api-key-signup.html
    private let apiKey = "oOmrSwfN79pdnObk07VfKO3hNuFqyRW4aYtGDytz"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    /// Search for foods in the USDA database
    /// - Parameters:
    ///   - query: Search term (e.g., "banana", "apple")
    ///   - page: Page number (1-indexed)
    ///   - pageSize: Number of results per page
    /// - Returns: Array of USDA food items
    func searchFoods(query: String, page: Int = 1, pageSize: Int = 25) async throws -> [USDAFoodItem] {
        guard var components = URLComponents(string: "\(baseURL)/foods/search") else {
            throw USDAError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            URLQueryItem(name: "pageNumber", value: "\(page)"),
            URLQueryItem(name: "api_key", value: apiKey),
            // SR Legacy has proper portion descriptions (medium, large, etc.)
            // Survey (FNDDS) uses numeric codes instead of text
            URLQueryItem(name: "dataType", value: "SR Legacy")
        ]
        
        guard let url = components.url else {
            throw USDAError.invalidURL
        }
        
        print("🌐 USDA API Request: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("BiteLedger - iOS Food Tracker", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.invalidResponse
        }
        
        print("🌐 USDA API Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ USDA API Error response: \(errorString)")
            }
            throw USDAError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        do {
            let searchResponse = try decoder.decode(USDASearchResponse.self, from: data)
            print("🌐 USDA decoded successfully: \(searchResponse.foods.count) foods")
            
            // Log first few foods for debugging
            for (index, food) in searchResponse.foods.prefix(3).enumerated() {
                print("🥕 Food \(index + 1): \(food.description)")
                print("   - FDC ID: \(food.fdcId)")
                print("   - Data Type: \(food.dataType)")
            }
            
            return searchResponse.foods
        } catch {
            print("❌ USDA Decoding error: \(error)")
            throw USDAError.decodingError(error)
        }
    }
    
    /// Get detailed information about a specific food
    /// - Parameter fdcId: The USDA FDC ID
    /// - Returns: Detailed food information
    func getFoodDetails(fdcId: Int) async throws -> USDAFoodDetail {
        guard var components = URLComponents(string: "\(baseURL)/food/\(fdcId)") else {
            throw USDAError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw USDAError.invalidURL
        }
        
        print("🌐 USDA Food Detail Request: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("BiteLedger - iOS Food Tracker", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw USDAError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(USDAFoodDetail.self, from: data)
    }
}

// MARK: - Response Models

struct USDASearchResponse: Codable {
    let foods: [USDAFoodItem]
    let totalHits: Int
    let currentPage: Int
    let totalPages: Int
}

struct USDAFoodItem: Codable, Identifiable {
    let fdcId: Int
    let description: String
    let dataType: String
    let brandOwner: String?
    let ingredients: String?
    let foodNutrients: [USDANutrient]?
    
    var id: Int { fdcId }
    
    var displayName: String {
        description
    }
    
    var displayBrand: String {
        brandOwner ?? "USDA"
    }
}

struct USDAFoodDetail: Codable {
    let fdcId: Int
    let description: String
    let dataType: String
    let foodNutrients: [USDANutrientDetail]
    let foodPortions: [USDAFoodPortion]?  // SR Legacy uses 'foodPortions'
    
    var displayName: String {
        description
    }
    
    var portions: [USDAFoodPortion]? {
        foodPortions
    }
}

struct USDANutrient: Codable {
    let nutrientId: Int
    let nutrientName: String
    let nutrientNumber: String?
    let value: Double
    let unitName: String
}

struct USDANutrientDetail: Codable {
    let nutrient: USDANutrientInfo
    let amount: Double?
    
    // Different data types use different field names
    private enum CodingKeys: String, CodingKey {
        case nutrient
        case amount
        case value  // SR Legacy uses 'value'
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nutrient = try container.decode(USDANutrientInfo.self, forKey: .nutrient)
        
        // Try 'amount' first (Survey/Foundation), then 'value' (SR Legacy)
        if let amt = try? container.decode(Double.self, forKey: .amount) {
            amount = amt
        } else if let val = try? container.decode(Double.self, forKey: .value) {
            amount = val
        } else {
            amount = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nutrient, forKey: .nutrient)
        try container.encodeIfPresent(amount, forKey: .amount)
    }
}

struct USDANutrientInfo: Codable {
    let id: Int
    let number: String
    let name: String
    let unitName: String
}

struct USDAFoodPortion: Codable {
    let id: Int
    let amount: Double?
    let modifier: String?
    let gramWeight: Double
    let sequenceNumber: Int?
    
    var displayName: String {
        let amt = amount ?? 1.0
        if let modifier = modifier {
            if amt == 1.0 {
                return modifier
            }
            return "\(amt) \(modifier)"
        }
        return "\(Int(gramWeight))g"
    }
}

// MARK: - Conversion Extensions

extension USDAFoodItem {
    /// Convert USDA food item to app's ProductInfo model for compatibility
    func toProductInfo() -> ProductInfo? {
        guard let nutrients = foodNutrients else { return nil }
        
        // Extract nutrition values (USDA provides per 100g)
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var sugar: Double = 0
        var sodium: Double = 0
        var saturatedFat: Double = 0
        
        for nutrient in nutrients {
            // USDA nutrient numbers: https://fdc.nal.usda.gov/api-guide.html
            switch nutrient.nutrientNumber {
            case "208": calories = nutrient.value  // Energy (kcal)
            case "203": protein = nutrient.value   // Protein
            case "205": carbs = nutrient.value     // Carbohydrate
            case "204": fat = nutrient.value       // Total lipid (fat)
            case "291": fiber = nutrient.value     // Fiber
            case "269": sugar = nutrient.value     // Sugars, total
            case "307": sodium = nutrient.value    // Sodium (mg)
            case "606": saturatedFat = nutrient.value  // Saturated fat
            default: break
            }
        }
        
        let nutriments = Nutriments(
            energyKcal100g: FlexibleDouble(calories),
            energyKcalComputed: calories,
            proteins100g: FlexibleDouble(protein),
            carbohydrates100g: FlexibleDouble(carbs),
            sugars100g: FlexibleDouble(sugar),
            fat100g: FlexibleDouble(fat),
            saturatedFat100g: FlexibleDouble(saturatedFat),
            transFat100g: nil,
            monounsaturatedFat100g: nil,
            polyunsaturatedFat100g: nil,
            fiber100g: FlexibleDouble(fiber),
            sodium100g: FlexibleDouble(sodium),
            salt100g: nil,
            cholesterol100g: nil,
            vitaminA100g: nil,
            vitaminC100g: nil,
            vitaminD100g: nil,
            calcium100g: nil,
            iron100g: nil,
            potassium100g: nil,
            energyKcalServing: nil,
            proteinsServing: nil,
            carbohydratesServing: nil,
            sugarsServing: nil,
            fatServing: nil,
            saturatedFatServing: nil,
            fiberServing: nil,
            sodiumServing: nil
        )
        
        return ProductInfo(
            code: "usda_\(fdcId)",
            productName: description,
            brands: brandOwner,
            imageUrl: nil,
            nutriments: nutriments,
            servingSize: "100g",
            quantity: nil,
            portions: nil,  // Search results don't include portions
            countriesTags: ["en:united-states"]  // USDA is US-only
        )
    }
}

extension USDAFoodDetail {
    /// Convert detailed USDA food to ProductInfo with portions
    func toProductInfo() -> ProductInfo {
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var sugar: Double = 0
        var sodium: Double = 0
        var saturatedFat: Double = 0
        var transFat: Double = 0
        var cholesterol: Double = 0
        var vitaminA: Double = 0
        var vitaminC: Double = 0
        var vitaminD: Double = 0
        var calcium: Double = 0
        var iron: Double = 0
        var potassium: Double = 0
        
        for nutrientDetail in foodNutrients {
            let nutrient = nutrientDetail.nutrient
            guard let amount = nutrientDetail.amount else { continue }
            
            switch nutrient.number {
            case "208": calories = amount
            case "203": protein = amount
            case "205": carbs = amount
            case "204": fat = amount
            case "291": fiber = amount
            case "269": sugar = amount
            case "307": sodium = amount / 1000  // Convert mg to g for consistency
            case "606": saturatedFat = amount
            case "605": transFat = amount
            case "601": cholesterol = amount / 1000  // Convert mg to g
            case "320": vitaminA = amount / 1000000  // Convert µg to g
            case "401": vitaminC = amount / 1000  // Convert mg to g
            case "324": vitaminD = amount / 1000000  // Convert µg to g
            case "301": calcium = amount / 1000  // Convert mg to g
            case "303": iron = amount / 1000  // Convert mg to g
            case "306": potassium = amount / 1000  // Convert mg to g
            default: break
            }
        }
        
        let nutriments = Nutriments(
            energyKcal100g: FlexibleDouble(calories),
            energyKcalComputed: calories,
            proteins100g: FlexibleDouble(protein),
            carbohydrates100g: FlexibleDouble(carbs),
            sugars100g: FlexibleDouble(sugar),
            fat100g: FlexibleDouble(fat),
            saturatedFat100g: FlexibleDouble(saturatedFat),
            transFat100g: FlexibleDouble(transFat),
            monounsaturatedFat100g: nil,
            polyunsaturatedFat100g: nil,
            fiber100g: FlexibleDouble(fiber),
            sodium100g: FlexibleDouble(sodium),
            salt100g: nil,
            cholesterol100g: FlexibleDouble(cholesterol),
            vitaminA100g: FlexibleDouble(vitaminA),
            vitaminC100g: FlexibleDouble(vitaminC),
            vitaminD100g: FlexibleDouble(vitaminD),
            calcium100g: FlexibleDouble(calcium),
            iron100g: FlexibleDouble(iron),
            potassium100g: FlexibleDouble(potassium),
            energyKcalServing: nil,
            proteinsServing: nil,
            carbohydratesServing: nil,
            sugarsServing: nil,
            fatServing: nil,
            saturatedFatServing: nil,
            fiberServing: nil,
            sodiumServing: nil
        )
        
        // Log all portions for debugging
        print("🍌 USDA Food: \(description)")
        print("🍌 Total portions available: \(portions?.count ?? 0)")
        portions?.forEach { portion in
            print("   - Portion: modifier='\(portion.modifier ?? "nil")', amount=\(portion.amount ?? 0), gramWeight=\(portion.gramWeight)")
        }
        
        // Convert USDA portions to ServingPortion (only if there are meaningful portions)
        let servingPortions = portions?.compactMap { portion -> ServingPortion? in
            guard let modifier = portion.modifier else {
                print("   ⚠️ Skipping portion with nil modifier")
                return nil
            }
            
            // Skip portions that are just "100g" equivalents
            if modifier.lowercased().contains("100 g") || modifier.lowercased().contains("100g") {
                print("   ⚠️ Skipping '100g' portion")
                return nil
            }
            
            // Skip portions that are numeric codes (Survey/FNDDS data)
            if modifier.range(of: "^[0-9]+$", options: .regularExpression) != nil {
                print("   ⚠️ Skipping numeric portion code: '\(modifier)'")
                return nil
            }
            
            // Clean up modifier for better display
            var cleanModifier = modifier
            
            // Simplify long descriptions but keep the size descriptors
            cleanModifier = cleanModifier
                .replacingOccurrences(of: " (7\" to 7-7/8\" long)", with: "")
                .replacingOccurrences(of: " (8\" to 8-7/8\" long)", with: "")
                .replacingOccurrences(of: " (6\" to 6-7/8\" long)", with: "")
                .replacingOccurrences(of: " (9\" or longer)", with: "")
                .replacingOccurrences(of: " (less than 6\" long)", with: "")
            
            // Skip NLEA serving in favor of the actual size-based portions
            if cleanModifier.lowercased() == "nlea serving" {
                print("   ⚠️ Skipping NLEA serving in favor of size-based portions")
                return nil
            }
            
            print("   ✅ Keeping portion: \(cleanModifier)")
            return ServingPortion(
                id: portion.id,
                amount: portion.amount ?? 1.0,
                modifier: cleanModifier,
                gramWeight: portion.gramWeight
            )
        }
        
        print("🍌 Filtered to \(servingPortions?.count ?? 0) meaningful portions")
        
        // Use first portion as default serving size, or 100g if none available
        let defaultServing: String
        if let firstPortion = servingPortions?.first {
            // Format: "1.0 medium (118g)" so the parser can extract gram weight
            let gramWeight = Int(firstPortion.gramWeight)
            defaultServing = "1.0 \(firstPortion.modifier) (\(gramWeight)g)"
        } else {
            defaultServing = "100g"
        }
        
        // Create a human-readable list of available portions
        let portionsList = servingPortions?.map { portion in
            "\(portion.modifier): \(Int(portion.gramWeight))g"
        }.joined(separator: ", ")
        
        print("🍌 Default serving: \(defaultServing)")
        print("🍌 Available portions: \(portionsList ?? "none")")
        
        return ProductInfo(
            code: "usda_\(fdcId)",
            productName: description,
            brands: "USDA",
            imageUrl: nil,
            nutriments: nutriments,
            servingSize: defaultServing,
            quantity: portionsList, // Store portions info for reference
            portions: servingPortions,
            countriesTags: ["en:united-states"]  // USDA is US-only
        )
    }
}

// MARK: - Errors

enum USDAError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not create valid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "Server error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noAPIKey:
            return "No USDA API key configured. Get one at https://fdc.nal.usda.gov/api-key-signup.html"
        }
    }
}
