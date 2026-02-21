import Foundation

// MARK: - Unified Food Search Service

/// Combines multiple food databases (USDA and OpenFoodFacts) for comprehensive search results
@MainActor
class UnifiedFoodSearchService {
    static let shared = UnifiedFoodSearchService()
    
    private let usdaService = USDAFoodDataService.shared
    private let openFoodFactsService = OpenFoodFactsService.shared
    
    private init() {}
    
    /// Search both USDA and OpenFoodFacts databases and merge results
    /// - USDA results appear first (better for whole foods)
    /// - OpenFoodFacts results appear second (better for packaged products)
    func searchAllDatabases(query: String) async throws -> [ProductInfo] {
        // Search both databases in parallel
        async let usdaResults = searchUSDA(query: query)
        async let openFoodResults = searchOpenFoodFacts(query: query)

        var allResults: [ProductInfo] = []

        // USDA first (better for fruits, vegetables, whole foods)
        do {
            let usda = try await usdaResults
            print("✅ USDA returned \(usda.count) results")
            allResults.append(contentsOf: usda)
        } catch {
            print("⚠️ USDA search failed: \(error.localizedDescription)")
        }

        // OpenFoodFacts second (better for packaged products)
        do {
            let openFood = try await openFoodResults
            print("✅ OpenFoodFacts returned \(openFood.count) results")
            allResults.append(contentsOf: openFood)
        } catch {
            print("⚠️ OpenFoodFacts search failed: \(error.localizedDescription)")
        }

        // If both failed, throw an error
        if allResults.isEmpty {
            throw UnifiedSearchError.noResults
        }

        // Sort by relevance - products with search terms in name rank higher
        let sortedResults = allResults.sorted { product1, product2 in
            let name1 = product1.productName?.lowercased() ?? ""
            let name2 = product2.productName?.lowercased() ?? ""
            let searchLower = query.lowercased()

            // Exact match in name ranks highest
            let exactMatch1 = name1 == searchLower
            let exactMatch2 = name2 == searchLower
            if exactMatch1 != exactMatch2 { return exactMatch1 }

            // Name starts with search ranks next
            let startsWith1 = name1.hasPrefix(searchLower)
            let startsWith2 = name2.hasPrefix(searchLower)
            if startsWith1 != startsWith2 { return startsWith1 }

            // Name contains search as whole phrase ranks next
            let containsPhrase1 = name1.contains(searchLower)
            let containsPhrase2 = name2.contains(searchLower)
            if containsPhrase1 != containsPhrase2 { return containsPhrase1 }

            // Otherwise keep original order (USDA first, then OpenFoodFacts)
            return false
        }

        return sortedResults
    }
    
    /// Search only USDA database (best for whole foods)
    private func searchUSDA(query: String) async throws -> [ProductInfo] {
        let usdaFoods = try await usdaService.searchFoods(query: query)
        let products = usdaFoods.compactMap { $0.toProductInfo() }

        // Filter to ensure ALL search words are present
        let searchWords = query.lowercased().split(separator: " ").map { String($0) }
        let filtered = products.filter { product in
            let name = product.productName?.lowercased() ?? ""
            let brand = product.brands?.lowercased() ?? ""
            let combinedText = "\(name) \(brand)"

            // Check if ALL search words are present
            return searchWords.allSatisfy { word in
                combinedText.contains(word)
            }
        }

        return filtered
    }
    
    /// Search only OpenFoodFacts database (best for packaged products)
    /// Filters results to prefer US English language products
    private func searchOpenFoodFacts(query: String) async throws -> [ProductInfo] {
        let results = try await openFoodFactsService.searchProducts(query: query)

        // Filter results for US/English products with ALL search terms
        let filtered = results.filter { product in
            let name = product.productName?.lowercased() ?? ""
            let brand = product.brands?.lowercased() ?? ""
            let combinedText = "\(name) \(brand)"

            // Split search query into individual words
            let searchWords = query.lowercased().split(separator: " ").map { String($0) }

            // Check if ALL search words are present in name or brand
            let hasAllSearchTerms = searchWords.allSatisfy { word in
                combinedText.contains(word)
            }

            // Filter out products with non-Latin characters (non-English)
            let nameHasNonLatin = name.range(of: "[^\\x00-\\x7F]", options: .regularExpression) != nil
            let brandHasNonLatin = brand.range(of: "[^\\x00-\\x7F]", options: .regularExpression) != nil

            // Must have all search terms and be in English
            return hasAllSearchTerms && !nameHasNonLatin && !brandHasNonLatin
        }

        print("🌐 Filtered OpenFoodFacts from \(results.count) to \(filtered.count) US/English results")
        return filtered
    }
    
    /// Determine which database a product code belongs to
    func getDatabaseType(for code: String) -> DatabaseType {
        if code.hasPrefix("usda_") {
            return .usda
        }
        return .openFoodFacts
    }
    
    /// Get detailed information for a product from the appropriate database
    func getProductDetails(code: String) async throws -> ProductInfo {
        let dbType = getDatabaseType(for: code)
        
        switch dbType {
        case .usda:
            // Extract FDC ID from code (format: "usda_12345")
            let fdcIdString = code.replacingOccurrences(of: "usda_", with: "")
            guard let fdcId = Int(fdcIdString) else {
                throw UnifiedSearchError.invalidProductCode
            }
            let detail = try await usdaService.getFoodDetails(fdcId: fdcId)
            return detail.toProductInfo()
            
        case .openFoodFacts:
            return try await openFoodFactsService.fetchProduct(barcode: code)
        }
    }
}

// MARK: - Database Type

enum DatabaseType {
    case usda
    case openFoodFacts
    
    var displayName: String {
        switch self {
        case .usda:
            return "USDA"
        case .openFoodFacts:
            return "Open Food Facts"
        }
    }
}

// MARK: - Errors

enum UnifiedSearchError: LocalizedError {
    case noResults
    case invalidProductCode
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No results found in any database"
        case .invalidProductCode:
            return "Invalid product code format"
        }
    }
}
