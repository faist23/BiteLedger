import Foundation

// MARK: - Flexible Decoding

/// Handles decoding values that might be strings or numbers
struct FlexibleDouble: Codable {
    let value: Double
    
    init(_ value: Double) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self),
                  let doubleValue = Double(stringValue) {
            value = doubleValue
        } else {
            value = 0
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Service

/// Service for interacting with the Open Food Facts API
@MainActor
class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    
    private let baseURL = "https://world.openfoodfacts.org/api/v2"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    /// Fetch product information by barcode
    func fetchProduct(barcode: String) async throws -> ProductInfo {
        let urlString = "\(baseURL)/product/\(barcode).json"
        
        guard let url = URL(string: urlString) else {
            throw OpenFoodFactsError.invalidBarcode
        }
        
        print("📷 Barcode lookup: \(barcode)")
        print("🌐 URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.setValue("BiteLedger - iOS Food Tracker", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.invalidResponse
        }
        
        print("🌐 Barcode lookup status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw OpenFoodFactsError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Don't use convertFromSnakeCase - we have custom CodingKeys
        
        let apiResponse = try decoder.decode(OpenFoodFactsResponse.self, from: data)
        
        guard apiResponse.status == 1, let product = apiResponse.product else {
            print("❌ Product not found or invalid status")
            throw OpenFoodFactsError.productNotFound
        }
        
        print("📦 Found product: \(product.displayName)")
        print("   - Serving size: '\(product.servingSize ?? "nil")'")
        if let nutriments = product.nutriments {
            print("   - Calories: \(nutriments.calories)")
        } else {
            print("   - Nutriments: nil")
        }
        
        return product
    }
    
    /// Search for products by name
    func searchProducts(query: String, page: Int = 1) async throws -> [ProductInfo] {
        // Use the world endpoint for faster response, filter client-side
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl"

        guard var components = URLComponents(string: urlString) else {
            throw OpenFoodFactsError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,image_url,nutriments,serving_size,quantity,countries_tags")
        ]
        
        guard let url = components.url else {
            throw OpenFoodFactsError.invalidURL
        }
        
        print("🌐 API Request URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.setValue("BiteLedger - iOS Food Tracker", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.invalidResponse
        }
        
        print("🌐 API Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw OpenFoodFactsError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        // Don't use convertFromSnakeCase - we have custom CodingKeys
        
        do {
            let searchResponse = try decoder.decode(OpenFoodFactsSearchResponse.self, from: data)
            print("🌐 API decoded successfully: \(searchResponse.products.count) products")
            
            // Log first few products for debugging
            for (index, product) in searchResponse.products.prefix(3).enumerated() {
                print("📦 Product \(index + 1): \(product.displayName)")
                print("   - Barcode: \(product.code)")
                print("   - Brand: \(product.brands ?? "nil")")
                print("   - Serving: \(product.servingSize ?? "nil")")
                if let nutriments = product.nutriments {
                    print("   - Calories: \(nutriments.calories)")
                } else {
                    print("   - Nutriments: nil")
                }
            }
            
            return searchResponse.products
        } catch {
            print("❌ Decoding error: \(error)")
            throw OpenFoodFactsError.decodingError(error)
        }
    }
}

// MARK: - API Response Models

/// Response from the Open Food Facts API for a single product
struct OpenFoodFactsResponse: Codable {
    let status: Int
    let product: ProductInfo?
}

/// Response from the Open Food Facts search API
struct OpenFoodFactsSearchResponse: Codable {
    let count: Int
    let page: Int
    let pageSize: Int
    let products: [ProductInfo]
    
    enum CodingKeys: String, CodingKey {
        case count
        case page
        case pageSize = "page_size"
        case products
    }
}

/// Product information from Open Food Facts
struct ProductInfo: Codable, Identifiable {
    let code: String
    let productName: String?
    let brands: String?
    let imageUrl: String?
    let nutriments: Nutriments?
    let servingSize: String?
    let quantity: String?
    let portions: [ServingPortion]?  // USDA portions (e.g., "1 medium banana")
    let countriesTags: [String]?  // Countries where product is sold
    let lastUsed: Date?  // For My Foods - when this item was last used

    var id: String { code }
    
    var displayName: String {
        if let name = productName, !name.isEmpty {
            return name
        }
        return "Unknown Product"
    }
    
    var displayBrand: String {
        brands ?? "Unknown Brand"
    }
    
    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case imageUrl = "image_url"
        case nutriments
        case servingSize = "serving_size"
        case quantity
        case portions
        case countriesTags = "countries_tags"
        // lastUsed is not from API, so not in CodingKeys
    }
    
    // Custom initializer for creating ProductInfo manually (with lastUsed)
    init(code: String, productName: String?, brands: String?, imageUrl: String?, nutriments: Nutriments?, servingSize: String?, quantity: String?, portions: [ServingPortion]?, countriesTags: [String]?, lastUsed: Date?) {
        self.code = code
        self.productName = productName
        self.brands = brands
        self.imageUrl = imageUrl
        self.nutriments = nutriments
        self.servingSize = servingSize
        self.quantity = quantity
        self.portions = portions
        self.countriesTags = countriesTags
        self.lastUsed = lastUsed
    }
    
    // Custom decoder for API responses (lastUsed defaults to nil)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        productName = try? container.decode(String.self, forKey: .productName)
        brands = try? container.decode(String.self, forKey: .brands)
        imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        nutriments = try? container.decode(Nutriments.self, forKey: .nutriments)
        servingSize = try? container.decode(String.self, forKey: .servingSize)
        quantity = try? container.decode(String.self, forKey: .quantity)
        portions = try? container.decode([ServingPortion].self, forKey: .portions)
        countriesTags = try? container.decode([String].self, forKey: .countriesTags)
        lastUsed = nil  // Not from API
    }
}

/// Represents a serving portion (primarily from USDA)
struct ServingPortion: Codable, Identifiable, Hashable {
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

/// Nutrition information from Open Food Facts
struct Nutriments: Codable {
    // Per 100g values - these might be strings or numbers in the API
    let energyKcal100g: FlexibleDouble?
    let energyKcalComputed: Double?
    let proteins100g: FlexibleDouble?
    let carbohydrates100g: FlexibleDouble?
    let sugars100g: FlexibleDouble?
    let fat100g: FlexibleDouble?
    let saturatedFat100g: FlexibleDouble?
    let transFat100g: FlexibleDouble?
    let monounsaturatedFat100g: FlexibleDouble?
    let polyunsaturatedFat100g: FlexibleDouble?
    let fiber100g: FlexibleDouble?
    let sodium100g: FlexibleDouble?
    let salt100g: FlexibleDouble?
    let cholesterol100g: FlexibleDouble?
    
    // Vitamins and minerals
    let vitaminA100g: FlexibleDouble?
    let vitaminC100g: FlexibleDouble?
    let vitaminD100g: FlexibleDouble?
    let vitaminE100g: FlexibleDouble?
    let vitaminK100g: FlexibleDouble?
    let vitaminB6100g: FlexibleDouble?
    let vitaminB12100g: FlexibleDouble?
    let folate100g: FlexibleDouble?
    let choline100g: FlexibleDouble?
    let calcium100g: FlexibleDouble?
    let iron100g: FlexibleDouble?
    let potassium100g: FlexibleDouble?
    let magnesium100g: FlexibleDouble?
    let zinc100g: FlexibleDouble?
    let caffeine100g: FlexibleDouble?
    
    // Serving values (if available)
    let energyKcalServing: FlexibleDouble?
    let proteinsServing: FlexibleDouble?
    let carbohydratesServing: FlexibleDouble?
    let sugarsServing: FlexibleDouble?
    let fatServing: FlexibleDouble?
    let saturatedFatServing: FlexibleDouble?
    let fiberServing: FlexibleDouble?
    let sodiumServing: FlexibleDouble?
    // Per-serving minerals/vitamins (FatSecret only — not in OpenFoodFacts JSON)
    // These use default values so CodingKeys-based synthesis still works for OFf responses.
    var potassiumServing: FlexibleDouble? = nil   // mg/serving
    var cholesterolServing: FlexibleDouble? = nil // mg/serving
    var calciumServing: FlexibleDouble? = nil     // mg/serving
    var ironServing: FlexibleDouble? = nil        // mg/serving
    var vitaminAServing: FlexibleDouble? = nil    // mcg/serving
    var vitaminCServing: FlexibleDouble? = nil    // mg/serving
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcalComputed = "energy-kcal_value_computed"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case transFat100g = "trans-fat_100g"
        case monounsaturatedFat100g = "monounsaturated-fat_100g"
        case polyunsaturatedFat100g = "polyunsaturated-fat_100g"
        case fiber100g = "fiber_100g"
        case sodium100g = "sodium_100g"
        case salt100g = "salt_100g"
        case cholesterol100g = "cholesterol_100g"
        case vitaminA100g = "vitamin-a_100g"
        case vitaminC100g = "vitamin-c_100g"
        case vitaminD100g = "vitamin-d_100g"
        case vitaminE100g = "vitamin-e_100g"
        case vitaminK100g = "vitamin-k_100g"
        case vitaminB6100g = "vitamin-b6_100g"
        case vitaminB12100g = "vitamin-b12_100g"
        case folate100g = "folate_100g"
        case choline100g = "choline_100g"
        case calcium100g = "calcium_100g"
        case iron100g = "iron_100g"
        case potassium100g = "potassium_100g"
        case magnesium100g = "magnesium_100g"
        case zinc100g = "zinc_100g"
        case caffeine100g = "caffeine_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteinsServing = "proteins_serving"
        case carbohydratesServing = "carbohydrates_serving"
        case sugarsServing = "sugars_serving"
        case fatServing = "fat_serving"
        case saturatedFatServing = "saturated-fat_serving"
        case fiberServing = "fiber_serving"
        case sodiumServing = "sodium_serving"
    }
    
    var calories: Double {
        // Prefer the computed value if energy-kcal_100g is 0
        if let kcal = energyKcal100g?.value, kcal > 0 {
            return kcal
        }
        return energyKcalComputed ?? 0
    }
    
    /// Determine the nutrition reference type for this product
    /// - Parameter servingGrams: The gram weight of the serving size, if known (0 if unknown)
    func nutritionReferenceType(servingGrams: Double = -1) -> String {
        // If serving has no gram weight (0g), prefer per-serving data if available
        if servingGrams == 0, let servingCal = energyKcalServing?.value, servingCal > 0 {
            return "perServing"
        }
        
        // Check if we have actual per-100g data
        if let kcal100g = energyKcal100g?.value, kcal100g > 0 {
            return "per100g"
        } else if let servingCal = energyKcalServing?.value, servingCal > 0 {
            return "perServing"
        }
        return "per100g"  // Default
    }
    
    /// Convert to app's NutritionFacts model
    /// - Parameters:
    ///   - servingMultiplier: Multiplier for nutrition values
    ///   - servingGrams: Gram weight of serving (0 if unknown, use per-serving data)
    func toNutritionFacts(servingMultiplier: Double = 1.0, servingGrams: Double = -1) -> NutritionFacts {
        // Prefer per-100g values, but fall back to per-serving values if available (e.g., FatSecret)
        // For per-serving values, apply the multiplier directly (it's already per serving)
        let caloriesValue: Double
        let proteinValue: Double
        let carbsValue: Double
        let fatValue: Double
        let fiberValue: Double
        let sugarValue: Double
        let sodiumValue: Double
        let saturatedFatValue: Double
        
        print("🍽️ toNutritionFacts called with multiplier: \(servingMultiplier), servingGrams: \(servingGrams)")
        print("🍽️ energyKcal100g: \(energyKcal100g?.value ?? 0)")
        print("🍽️ energyKcalServing: \(energyKcalServing?.value ?? 0)")
        
        // Prefer per-serving data if it exists (FatSecret, manually entered foods with perServing type)
        // This handles both cases: servingGrams == 0 (FatSecret) and servingGrams > 0 (Halos)
        let hasServingData = energyKcalServing?.value ?? 0 > 0
        
        // Check if we have actual per-100g data (not just computed calories)
        // Only use per-100g if we don't have serving data
        if !hasServingData, let kcal100g = energyKcal100g?.value, kcal100g > 0 {
            // Has per-100g data - use it with multiplier
            print("🍽️ Using per-100g nutrition data")
            caloriesValue = kcal100g * servingMultiplier
            proteinValue = (proteins100g?.value ?? 0) * servingMultiplier
            carbsValue = (carbohydrates100g?.value ?? 0) * servingMultiplier
            fatValue = (fat100g?.value ?? 0) * servingMultiplier
            fiberValue = (fiber100g?.value ?? 0) * servingMultiplier
            sugarValue = (sugars100g?.value ?? 0) * servingMultiplier
            sodiumValue = (sodium100g?.value ?? 0) * servingMultiplier
            saturatedFatValue = (saturatedFat100g?.value ?? 0) * servingMultiplier
        } else if let servingCal = energyKcalServing?.value, servingCal > 0 {
            // Has per-serving data (e.g., FatSecret or items with no gram weight) - use it with multiplier
            print("🍽️ Using per-serving nutrition data: \(servingCal) cal")
            caloriesValue = servingCal * servingMultiplier
            proteinValue = (proteinsServing?.value ?? 0) * servingMultiplier
            carbsValue = (carbohydratesServing?.value ?? 0) * servingMultiplier
            fatValue = (fatServing?.value ?? 0) * servingMultiplier
            fiberValue = (fiberServing?.value ?? 0) * servingMultiplier
            sugarValue = (sugarsServing?.value ?? 0) * servingMultiplier
            sodiumValue = (sodiumServing?.value ?? 0) * servingMultiplier
            saturatedFatValue = (saturatedFatServing?.value ?? 0) * servingMultiplier
            print("🍽️ Calculated values - cal: \(caloriesValue), protein: \(proteinValue), carbs: \(carbsValue), fat: \(fatValue), fiber: \(fiberValue), sugar: \(sugarValue), sodium(g): \(sodiumValue)")
        } else {
            // No data
            print("🍽️ No nutrition data available")
            caloriesValue = 0
            proteinValue = 0
            carbsValue = 0
            fatValue = 0
            fiberValue = 0
            sugarValue = 0
            sodiumValue = 0
            saturatedFatValue = 0
        }
        
        // Per-100g micronutrient fields must be scaled by grams, not serving count.
        // When using per-serving data with a known gramWeight, derive the gram-based multiplier.
        // Otherwise fall back to servingMultiplier (correct for the per-100g path where
        // servingMultiplier == totalGrams/100 already).
        let microMultiplier: Double
        if hasServingData && servingGrams > 0 {
            microMultiplier = servingGrams * servingMultiplier / 100.0
        } else {
            microMultiplier = servingMultiplier
        }

        return NutritionFacts(
            caloriesPer100g: caloriesValue,
            proteinPer100g: proteinValue,
            carbsPer100g: carbsValue,
            fatPer100g: fatValue,
            fiberPer100g: fiberValue,
            sugarPer100g: sugarValue,
            sodiumPer100g: sodiumValue,
            saturatedFatPer100g: saturatedFatValue,
            transFatPer100g: (transFat100g?.value ?? 0) * microMultiplier,
            monounsaturatedFatPer100g: (monounsaturatedFat100g?.value ?? 0) * microMultiplier,
            polyunsaturatedFatPer100g: (polyunsaturatedFat100g?.value ?? 0) * microMultiplier,
            cholesterolPer100g: (cholesterol100g?.value ?? 0) * microMultiplier,
            magnesiumPer100g: (magnesium100g?.value ?? 0) * microMultiplier,
            zincPer100g: (zinc100g?.value ?? 0) * microMultiplier,
            vitaminAPer100g: (vitaminA100g?.value ?? 0) * microMultiplier,
            vitaminCPer100g: (vitaminC100g?.value ?? 0) * microMultiplier,
            vitaminDPer100g: (vitaminD100g?.value ?? 0) * microMultiplier,
            vitaminEPer100g: (vitaminE100g?.value ?? 0) * microMultiplier,
            vitaminKPer100g: (vitaminK100g?.value ?? 0) * microMultiplier,
            vitaminB6Per100g: (vitaminB6100g?.value ?? 0) * microMultiplier,
            vitaminB12Per100g: (vitaminB12100g?.value ?? 0) * microMultiplier,
            folatePer100g: (folate100g?.value ?? 0) * microMultiplier,
            cholinePer100g: (choline100g?.value ?? 0) * microMultiplier,
            calciumPer100g: (calcium100g?.value ?? 0) * microMultiplier,
            ironPer100g: (iron100g?.value ?? 0) * microMultiplier,
            potassiumPer100g: (potassium100g?.value ?? 0) * microMultiplier,
            caffeinePer100g: (caffeine100g?.value ?? 0) * microMultiplier
        )
    }
}

// MARK: - Errors

enum OpenFoodFactsError: LocalizedError {
    case invalidBarcode
    case invalidURL
    case invalidResponse
    case productNotFound
    case httpError(statusCode: Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "Invalid barcode format"
        case .invalidURL:
            return "Could not create valid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .productNotFound:
            return "Product not found in database"
        case .httpError(let statusCode):
            return "Server error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
