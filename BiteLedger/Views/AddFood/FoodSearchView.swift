import SwiftUI
import SwiftData

/// Unified food search view - handles barcode, search, and manual entry
struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodLog.timestamp, order: .reverse) private var allLogs: [FoodLog]
    
    let mealType: MealType
    let onFoodAdded: (AddedFoodItem) -> Void
    
    @State private var searchText = ""
    @State private var selectedTab: SearchTab = .search
    @State private var searchResults: [ProductInfo] = []
    @State private var isSearching = false
    @State private var showBarcodeScanner = false
    @State private var showManualEntry = false
    @State private var selectedProduct: ProductInfo?
    @State private var selectedProductContext: (product: ProductInfo, existingFood: FoodItem?, initialAmount: Double?)? // Combined context
    @State private var selectedMeal: [FoodLog]?
    @State private var errorMessage: String?
    
    private let foodService = UnifiedFoodSearchService.shared
    
    enum SearchTab: String, CaseIterable {
        case search = "Search"
        case myFoods = "My Foods"
        case meals = "Meals"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) { _, newValue in
                            if selectedTab == .search && !newValue.isEmpty {
                                performSearch()
                            }
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .padding()
                
                // Tabs
                Picker("Search Type", selection: $selectedTab) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Quick actions
                if selectedTab == .search {
                    HStack(spacing: 12) {
                        Button {
                            showBarcodeScanner = true
                        } label: {
                            Label("Scan", systemImage: "barcode.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Button {
                            showManualEntry = true
                        } label: {
                            Label("Manual", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                    .padding(.horizontal)
                }
                
                // Tab content
                Group {
                    switch selectedTab {
                    case .search:
                        searchTabContent
                    case .myFoods:
                        myFoodsTabContent
                    case .meals:
                        mealsTabContent
                    }
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                BarcodeScannerView { barcode in
                    fetchProductByBarcode(barcode)
                }
            }
            .sheet(item: $selectedProduct) { product in
                ImprovedServingPicker(
                    product: product,
                    mealType: mealType
                ) { addedItem in
                    onFoodAdded(addedItem)
                    dismiss()
                }
            }
            .sheet(item: Binding(
                get: { selectedProductContext.map { ProductContext(id: UUID(), product: $0.product, existingFood: $0.existingFood, initialServingAmount: $0.initialAmount) } },
                set: { selectedProductContext = $0.map { ($0.product, $0.existingFood, $0.initialServingAmount) } }
            )) { context in
                ImprovedServingPicker(
                    product: context.product,
                    mealType: mealType,
                    existingFoodItem: context.existingFood,
                    initialServingAmount: context.initialServingAmount
                ) { addedItem in
                    onFoodAdded(addedItem)
                    selectedProductContext = nil
                    dismiss()
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualFoodEntryView(mealType: mealType) { addedItem in
                    onFoodAdded(addedItem)
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Tab Content Views
    
    private var searchTabContent: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("Try a different search term or use manual entry")
                }
            } else if searchResults.isEmpty && searchText.isEmpty {
                // Show recent foods for this meal type
                RecentFoodsForMealView(
                    allLogs: allLogs,
                    mealType: mealType,
                    onFoodSelected: { foodItem in
                        // Find the most recent log entry for this food item
                        let mostRecentLog = allLogs.first { $0.foodItem?.id == foodItem.id }
                        let lastServingAmount = mostRecentLog?.servingMultiplier ?? 1.0
                        
                        let servingSizeString: String
                        if let recentLog = mostRecentLog {
                            servingSizeString = "\(recentLog.servingMultiplier) \(foodItem.servingDescription) (\(Int(recentLog.totalGrams))g)"
                        } else {
                            servingSizeString = "\(foodItem.servingDescription) (\(Int(foodItem.gramsPerServing))g)"
                        }
                        
                        let productInfo = ProductInfo(
                            code: foodItem.barcode ?? "",
                            productName: foodItem.name,
                            brands: foodItem.brand,
                            imageUrl: foodItem.imageURL,
                            nutriments: Nutriments(
                                energyKcal100g: FlexibleDouble(foodItem.caloriesPer100g),
                                energyKcalComputed: foodItem.caloriesPer100g,
                                proteins100g: FlexibleDouble(foodItem.proteinPer100g),
                                carbohydrates100g: FlexibleDouble(foodItem.carbsPer100g),
                                sugars100g: foodItem.sugarPer100g.map { FlexibleDouble($0) },
                                fat100g: FlexibleDouble(foodItem.fatPer100g),
                                saturatedFat100g: foodItem.saturatedFatPer100g.map { FlexibleDouble($0) },
                                transFat100g: foodItem.transFatPer100g.map { FlexibleDouble($0) },
                                monounsaturatedFat100g: foodItem.monounsaturatedFatPer100g.map { FlexibleDouble($0) },
                                polyunsaturatedFat100g: foodItem.polyunsaturatedFatPer100g.map { FlexibleDouble($0) },
                                fiber100g: foodItem.fiberPer100g.map { FlexibleDouble($0) },
                                sodium100g: foodItem.sodiumPer100g.map { FlexibleDouble($0) },
                                salt100g: nil,
                                cholesterol100g: foodItem.cholesterolPer100g.map { FlexibleDouble($0) },
                                vitaminA100g: foodItem.vitaminAPer100g.map { FlexibleDouble($0) },
                                vitaminC100g: foodItem.vitaminCPer100g.map { FlexibleDouble($0) },
                                vitaminD100g: foodItem.vitaminDPer100g.map { FlexibleDouble($0) },
                                calcium100g: foodItem.calciumPer100g.map { FlexibleDouble($0) },
                                iron100g: foodItem.ironPer100g.map { FlexibleDouble($0) },
                                potassium100g: foodItem.potassiumPer100g.map { FlexibleDouble($0) },
                                energyKcalServing: nil,
                                proteinsServing: nil,
                                carbohydratesServing: nil,
                                sugarsServing: nil,
                                fatServing: nil,
                                saturatedFatServing: nil,
                                fiberServing: nil,
                                sodiumServing: nil
                            ),
                            servingSize: servingSizeString,
                            quantity: "\(Int(foodItem.gramsPerServing))g",
                            portions: nil,
            countriesTags: nil
                        )
                        selectedProductContext = (productInfo, foodItem, lastServingAmount)
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults, id: \.code) { product in
                            ProductQuickRow(product: product)
                                .onTapGesture {
                                    handleProductSelection(product)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var myFoodsTabContent: some View {
        MyFoodsListView(
            allLogs: allLogs,
            searchText: searchText,
            mealType: mealType,
            onFoodSelected: { foodItem in
                // Find the most recent log entry for this food item to get the last used serving
                let mostRecentLog = allLogs.first { $0.foodItem?.id == foodItem.id }
                
                // Convert FoodItem to ProductInfo for the serving picker
                // Use the most recent serving multiplier if available
                let lastServingAmount = mostRecentLog?.servingMultiplier ?? 1.0
                let servingSizeString: String
                
                if let recentLog = mostRecentLog {
                    // Use the actual serving from the last time this was logged
                    servingSizeString = "\(recentLog.servingMultiplier) \(foodItem.servingDescription) (\(Int(recentLog.totalGrams))g)"
                } else {
                    servingSizeString = "\(foodItem.servingDescription) (\(Int(foodItem.gramsPerServing))g)"
                }
                
                let productInfo = ProductInfo(
                    code: foodItem.barcode ?? "",
                    productName: foodItem.name,
                    brands: foodItem.brand,
                    imageUrl: foodItem.imageURL,
                    nutriments: Nutriments(
                        energyKcal100g: FlexibleDouble(foodItem.caloriesPer100g),
                        energyKcalComputed: foodItem.caloriesPer100g,
                        proteins100g: FlexibleDouble(foodItem.proteinPer100g),
                        carbohydrates100g: FlexibleDouble(foodItem.carbsPer100g),
                        sugars100g: foodItem.sugarPer100g.map { FlexibleDouble($0) },
                        fat100g: FlexibleDouble(foodItem.fatPer100g),
                        saturatedFat100g: foodItem.saturatedFatPer100g.map { FlexibleDouble($0) },
                        transFat100g: foodItem.transFatPer100g.map { FlexibleDouble($0) },
                        monounsaturatedFat100g: foodItem.monounsaturatedFatPer100g.map { FlexibleDouble($0) },
                        polyunsaturatedFat100g: foodItem.polyunsaturatedFatPer100g.map { FlexibleDouble($0) },
                        fiber100g: foodItem.fiberPer100g.map { FlexibleDouble($0) },
                        sodium100g: foodItem.sodiumPer100g.map { FlexibleDouble($0) },
                        salt100g: nil,
                        cholesterol100g: foodItem.cholesterolPer100g.map { FlexibleDouble($0) },
                        vitaminA100g: foodItem.vitaminAPer100g.map { FlexibleDouble($0) },
                        vitaminC100g: foodItem.vitaminCPer100g.map { FlexibleDouble($0) },
                        vitaminD100g: foodItem.vitaminDPer100g.map { FlexibleDouble($0) },
                        calcium100g: foodItem.calciumPer100g.map { FlexibleDouble($0) },
                        iron100g: foodItem.ironPer100g.map { FlexibleDouble($0) },
                        potassium100g: foodItem.potassiumPer100g.map { FlexibleDouble($0) },
                        energyKcalServing: nil,
                        proteinsServing: nil,
                        carbohydratesServing: nil,
                        sugarsServing: nil,
                        fatServing: nil,
                        saturatedFatServing: nil,
                        fiberServing: nil,
                        sodiumServing: nil
                    ),
                    servingSize: servingSizeString,
                    quantity: "\(Int(foodItem.gramsPerServing))g",
                    portions: nil,
            countriesTags: nil
                )
                selectedProductContext = (productInfo, foodItem, lastServingAmount)
            }
        )
    }
    
    private var groupedMeals: [(date: Date, mealType: MealType, logs: [FoodLog])] {
        let grouped = Dictionary(grouping: allLogs) { log -> String in
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: log.timestamp)
            let dateKey = calendar.date(from: dateComponents) ?? log.timestamp
            return "\(dateKey)-\(log.meal.rawValue)"
        }
        
        return grouped.map { (_, logs) -> (date: Date, mealType: MealType, logs: [FoodLog]) in
            let firstLog = logs.first!
            return (firstLog.timestamp, firstLog.meal, logs.sorted { $0.timestamp < $1.timestamp })
        }
        .sorted { $0.date > $1.date }
        .filter { meal in
            if searchText.isEmpty { return true }
            return meal.logs.contains { log in
                log.foodItem?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
    
    private var mealsTabContent: some View {
        Group {
            if groupedMeals.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "No Meals Yet" : "No Matching Meals", systemImage: "list.bullet.clipboard")
                } description: {
                    Text(searchText.isEmpty ? "Your logged meals will appear here" : "No meals contain '\(searchText)'")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(groupedMeals, id: \.date) { meal in
                            VStack(alignment: .leading, spacing: 8) {
                                // Meal header
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(meal.mealType.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text(meal.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(meal.logs.count) items")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Text("\(Int(meal.logs.reduce(0) { $0 + $1.calories })) cal")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                
                                // Food items preview
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(meal.logs.prefix(3)) { log in
                                        if let foodItem = log.foodItem {
                                            HStack {
                                                Text("• \(foodItem.name)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                Text("\(Int(log.calories)) cal")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    
                                    if meal.logs.count > 3 {
                                        Text("+ \(meal.logs.count - 3) more")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding()
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                selectedMeal = meal.logs
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedMeal != nil ? SelectedMeal(logs: selectedMeal!) : nil },
            set: { selectedMeal = $0?.logs }
        )) { mealWrapper in
            MealItemSelectionView(
                sourceLogs: mealWrapper.logs,
                targetMealType: mealType,
                onAdd: { selectedLogs in
                    // Batch add selected logs
                    for log in selectedLogs {
                        if let foodItem = log.foodItem {
                            let addedItem = AddedFoodItem(
                                foodItem: foodItem,
                                servings: log.servingMultiplier,
                                totalGrams: log.totalGrams,
                                selectedPortionId: log.selectedPortionId
                            )
                            onFoodAdded(addedItem)
                        }
                    }
                    dismiss()
                }
            )
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        errorMessage = nil

        Task {
            // Search My Foods first
            let myFoodsResults = searchMyFoods(query: searchText)
            print("📱 Found \(myFoodsResults.count) My Foods results")

            do {
                print("🔍 Searching for: \(searchText)")
                let results = try await foodService.searchAllDatabases(query: searchText)
                print("📦 Got \(results.count) database results")

                await MainActor.run {
                    // Filter out products without nutrition data
                    let filteredResults = results.filter {
                        if let nutriments = $0.nutriments {
                            let hasCalories = nutriments.calories > 0
                            if !hasCalories {
                                print("⚠️ Filtered out \($0.displayName) - no calories")
                            }
                            return hasCalories
                        }
                        print("⚠️ Filtered out \($0.displayName) - no nutriments")
                        return false
                    }

                    // Combine My Foods (first) + database results
                    searchResults = myFoodsResults + filteredResults

                    print("✅ Total results: \(searchResults.count) (\(myFoodsResults.count) from My Foods)")

                    if searchResults.isEmpty {
                        errorMessage = "No results found for '\(searchText)'"
                    }
                    isSearching = false
                }
            } catch {
                print("❌ Search error: \(error)")
                await MainActor.run {
                    // Even if database search fails, show My Foods results
                    searchResults = myFoodsResults

                    if searchResults.isEmpty {
                        errorMessage = "Search failed: \(error.localizedDescription)"
                    }
                    isSearching = false
                }
            }
        }
    }

    private func searchMyFoods(query: String) -> [ProductInfo] {
        // Get unique food items from logs
        let uniqueFoods = Dictionary(grouping: allLogs.compactMap { $0.foodItem }) { $0.id }
            .values
            .compactMap { $0.first }

        // Split search query into words
        let searchWords = query.lowercased().split(separator: " ").map { String($0) }

        // Filter foods that contain ALL search words
        let matchingFoods = uniqueFoods.filter { foodItem in
            let name = foodItem.name.lowercased()
            let brand = foodItem.brand?.lowercased() ?? ""
            let combinedText = "\(name) \(brand)"

            return searchWords.allSatisfy { word in
                combinedText.contains(word)
            }
        }

        // Convert to ProductInfo
        return matchingFoods.map { foodItem in
            ProductInfo(
                code: foodItem.barcode ?? "myfoods_\(foodItem.id.uuidString)",
                productName: foodItem.name,
                brands: foodItem.brand,
                imageUrl: foodItem.imageURL,
                nutriments: Nutriments(
                    energyKcal100g: FlexibleDouble(foodItem.caloriesPer100g),
                    energyKcalComputed: foodItem.caloriesPer100g,
                    proteins100g: FlexibleDouble(foodItem.proteinPer100g),
                    carbohydrates100g: FlexibleDouble(foodItem.carbsPer100g),
                    sugars100g: foodItem.sugarPer100g.map { FlexibleDouble($0) },
                    fat100g: FlexibleDouble(foodItem.fatPer100g),
                    saturatedFat100g: foodItem.saturatedFatPer100g.map { FlexibleDouble($0) },
                    transFat100g: foodItem.transFatPer100g.map { FlexibleDouble($0) },
                    monounsaturatedFat100g: foodItem.monounsaturatedFatPer100g.map { FlexibleDouble($0) },
                    polyunsaturatedFat100g: foodItem.polyunsaturatedFatPer100g.map { FlexibleDouble($0) },
                    fiber100g: foodItem.fiberPer100g.map { FlexibleDouble($0) },
                    sodium100g: foodItem.sodiumPer100g.map { FlexibleDouble($0) },
                    salt100g: nil,
                    cholesterol100g: foodItem.cholesterolPer100g.map { FlexibleDouble($0) },
                    vitaminA100g: foodItem.vitaminAPer100g.map { FlexibleDouble($0) },
                    vitaminC100g: foodItem.vitaminCPer100g.map { FlexibleDouble($0) },
                    vitaminD100g: foodItem.vitaminDPer100g.map { FlexibleDouble($0) },
                    calcium100g: foodItem.calciumPer100g.map { FlexibleDouble($0) },
                    iron100g: foodItem.ironPer100g.map { FlexibleDouble($0) },
                    potassium100g: foodItem.potassiumPer100g.map { FlexibleDouble($0) },
                    energyKcalServing: nil,
                    proteinsServing: nil,
                    carbohydratesServing: nil,
                    sugarsServing: nil,
                    fatServing: nil,
                    saturatedFatServing: nil,
                    fiberServing: nil,
                    sodiumServing: nil
                ),
                servingSize: "\(foodItem.gramsPerServing)g",
                quantity: "\(Int(foodItem.gramsPerServing))g",
                portions: nil,
                countriesTags: nil
            )
        }
    }
    
    private func fetchProductByBarcode(_ barcode: String) {
        errorMessage = nil
        
        Task {
            do {
                // Barcode lookup only works with OpenFoodFacts
                let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
                await MainActor.run {
                    if let nutriments = product.nutriments, nutriments.calories > 0 {
                        selectedProduct = product
                    } else {
                        errorMessage = "Product found but missing nutrition data. Use manual entry."
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Product not found in database. Try manual entry."
                }
            }
        }
    }
    
    private func handleProductSelection(_ product: ProductInfo) {
        // Check if this is a USDA product
        if product.code.hasPrefix("usda_") {
            // Fetch full details to get portions
            Task {
                do {
                    let detailedProduct = try await UnifiedFoodSearchService.shared.getProductDetails(code: product.code)
                    await MainActor.run {
                        selectedProduct = detailedProduct
                    }
                } catch {
                    print("❌ Failed to fetch USDA details: \(error)")
                    // Fall back to basic product if details fail
                    await MainActor.run {
                        selectedProduct = product
                    }
                }
            }
        } else {
            // OpenFoodFacts product - use as is
            selectedProduct = product
        }
    }
}

// MARK: - Supporting Views

// Helper struct for meal selection sheet binding
private struct SelectedMeal: Identifiable {
    let id = UUID()
    let logs: [FoodLog]
}

// Helper struct for product + existing food context
private struct ProductContext: Identifiable {
    let id: UUID
    let product: ProductInfo
    let existingFood: FoodItem?
    let initialServingAmount: Double?
}

struct ProductQuickRow: View {
    let product: ProductInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Product image thumbnail
            if let imageUrl = product.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
            
            // Product info
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let brand = product.brands, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                if let nutriments = product.nutriments {
                    Text("\(Int(nutriments.calories)) cal/100g")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer(minLength: 0)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct MyFoodsListView: View {
    let allLogs: [FoodLog]
    let searchText: String
    let mealType: MealType
    let onFoodSelected: (FoodItem) -> Void
    
    private var sortedFoods: [FoodItem] {
        let allFoodItems = allLogs.compactMap { $0.foodItem }
        let groupedByName = Dictionary(grouping: allFoodItems) { $0.name }
        
        // For each group, prefer FoodItems with better serving descriptions
        // (ones that don't end with "serving" or "g")
        let uniqueFoods = groupedByName.compactMap { (name, items) -> FoodItem? in
            // Prefer manual entries (better descriptions) over API entries
            let preferred = items.first { food in
                let desc = food.servingDescription.lowercased()
                return !desc.hasSuffix("serving") && !desc.hasSuffix("g")
            }
            return preferred ?? items.first
        }
        
        let filteredFoods = uniqueFoods.filter { food in
            searchText.isEmpty || food.name.localizedCaseInsensitiveContains(searchText)
        }
        return filteredFoods.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        Group {
            if sortedFoods.isEmpty {
                emptyStateView
            } else {
                foodListView
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(searchText.isEmpty ? "No Foods Yet" : "No Matching Foods", systemImage: "fork.knife")
        } description: {
            Text(searchText.isEmpty ? "Foods you add will appear here" : "No foods match '\(searchText)'")
        }
    }
    
    private var foodListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sortedFoods, id: \.id) { foodItem in
                    FoodItemRow(foodItem: foodItem, onTap: {
                        onFoodSelected(foodItem)
                    })
                }
            }
            .padding()
        }
    }
}

struct FoodItemRow: View {
    let foodItem: FoodItem
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            foodImageView
            
            VStack(alignment: .leading, spacing: 2) {
                Text(foodItem.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let brand = foodItem.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text("\(Int(foodItem.caloriesPer100g)) cal/\(foodItem.servingDescription)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            
            Spacer(minLength: 0)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            onTap()
        }
    }
    
    @ViewBuilder
    private var foodImageView: some View {
        if let imageURL = foodItem.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Recent Foods View

struct RecentFoodsForMealView: View {
    let allLogs: [FoodLog]
    let mealType: MealType
    let onFoodSelected: (FoodItem) -> Void
    
    private var recentFoods: [FoodItem] {
        // Get all logs for this meal type
        let mealLogs = allLogs.filter { $0.meal == mealType }
        
        // Get food items already logged today for this meal
        let todaysFoodIDs = Set(
            allLogs
                .filter { Calendar.current.isDate($0.timestamp, inSameDayAs: Date()) && $0.meal == mealType }
                .compactMap { $0.foodItem?.id }
        )
        
        // Get unique food items, excluding today's foods
        var seenFoodIDs = Set<UUID>()
        var uniqueFoods: [FoodItem] = []
        
        for log in mealLogs {
            guard let foodItem = log.foodItem else { continue }
            
            // Skip if already logged today
            if todaysFoodIDs.contains(foodItem.id) { continue }
            
            // Skip if we've already added this food
            if seenFoodIDs.contains(foodItem.id) { continue }
            
            seenFoodIDs.insert(foodItem.id)
            uniqueFoods.append(foodItem)
            
            // Stop at 10 items
            if uniqueFoods.count >= 10 { break }
        }
        
        return uniqueFoods
    }
    
    var body: some View {
        Group {
            if recentFoods.isEmpty {
                ContentUnavailableView {
                    Label("No Recent Foods", systemImage: "clock")
                } description: {
                    Text("Foods you've added to \(mealType.rawValue.lowercased()) will appear here")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent \(mealType.rawValue)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(recentFoods, id: \.id) { foodItem in
                                FoodItemRow(foodItem: foodItem, onTap: {
                                    onFoodSelected(foodItem)
                                })
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

#Preview {
    FoodSearchView(mealType: .breakfast) { _ in }
        .modelContainer(for: FoodLog.self, inMemory: true)
}
