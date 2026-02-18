import SwiftUI
import SwiftData

/// Improved serving picker with unit conversion like LoseIt
struct ImprovedServingPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let product: ProductInfo
    let mealType: MealType
    let existingFoodItem: FoodItem? // If provided, reuse this instead of creating new
    let initialServingAmount: Double? // If provided, use this as the default amount
    let onAdd: (AddedFoodItem) -> Void
    
    @State private var wholeNumber: Int
    @State private var fraction: Fraction
    @State private var selectedUnit: ServingUnit
    @State private var availableUnits: [ServingUnit] = []
    
    private let foodType: FoodType
    private let productServingGrams: Double?
    
    enum Fraction: Double, CaseIterable, Identifiable {
        case zero = 0.0
        case quarter = 0.25
        case third = 0.33
        case half = 0.5
        case twoThirds = 0.67
        case threeQuarters = 0.75
        
        var id: Double { rawValue }
        
        var displayName: String {
            switch self {
            case .zero: return "0"
            case .quarter: return "1/4"
            case .third: return "1/3"
            case .half: return "1/2"
            case .twoThirds: return "2/3"
            case .threeQuarters: return "3/4"
            }
        }
    }
    
    init(product: ProductInfo, mealType: MealType, existingFoodItem: FoodItem? = nil, initialServingAmount: Double? = nil, onAdd: @escaping (AddedFoodItem) -> Void) {
        self.product = product
        self.mealType = mealType
        self.existingFoodItem = existingFoodItem
        self.initialServingAmount = initialServingAmount
        self.onAdd = onAdd
        
        // Infer food type for density calculations
        self.foodType = FoodType.infer(from: product.displayName)
        
        print("🔍 Product: \(product.displayName)")
        print("🔍 Serving size string from API: '\(product.servingSize ?? "nil")'")
        print("🔍 Initial serving amount: \(initialServingAmount ?? 0)")
        
        // Parse product's natural serving size
        if let parsed = ServingSizeParser.parse(product.servingSize) {
            print("✅ Parsed serving: \(parsed.amount) \(parsed.unit.rawValue), grams: \(parsed.grams ?? 0)")
            
            // Use initialServingAmount if provided, otherwise use parsed amount
            let amount = initialServingAmount ?? parsed.amount
            
            // Split amount into whole and fractional parts
            let whole = Int(amount)
            let fractionalPart = amount - Double(whole)
            
            // Find closest fraction
            let closestFraction = Fraction.allCases.min(by: { abs($0.rawValue - fractionalPart) < abs($1.rawValue - fractionalPart) }) ?? .zero
            
            print("✅ Setting initial amount to: \(whole) + \(closestFraction.displayName)")
            _wholeNumber = State(initialValue: whole)
            _fraction = State(initialValue: closestFraction)
            _selectedUnit = State(initialValue: parsed.unit)
            self.productServingGrams = parsed.grams
        } else {
            print("⚠️ Failed to parse serving size, using initial amount or defaulting to 100g")
            // Use initialServingAmount if provided, otherwise default to 100g
            let amount = initialServingAmount ?? 100
            let whole = Int(amount)
            let fractionalPart = amount - Double(whole)
            let closestFraction = Fraction.allCases.min(by: { abs($0.rawValue - fractionalPart) < abs($1.rawValue - fractionalPart) }) ?? .zero
            
            _wholeNumber = State(initialValue: whole)
            _fraction = State(initialValue: closestFraction)
            _selectedUnit = State(initialValue: .gram)
            self.productServingGrams = amount
        }
    }
    
    private var amountValue: Double {
        Double(wholeNumber) + fraction.rawValue
    }
    
    private var totalGrams: Double {
        if selectedUnit == .serving, let servingGrams = productServingGrams {
            return amountValue * servingGrams
        }
        let density = ServingUnit.densityFor(foodType: foodType)
        return selectedUnit.toGrams(amount: amountValue, density: density)
    }
    
    private var nutritionMultiplier: Double {
        totalGrams / 100.0
    }
    
    private var calculatedNutrition: NutritionFacts? {
        product.nutriments?.toNutritionFacts(servingMultiplier: nutritionMultiplier)
    }
    
    private var nutritionPer100g: NutritionFacts? {
        product.nutriments?.toNutritionFacts(servingMultiplier: 1.0)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Product header
                HStack(spacing: 12) {
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
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.headline)
                            .lineLimit(2)
                        
                        if let brand = product.brands {
                            Text(brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                Spacer()
                
                // Nutrition display - centered
                if let nutrition = calculatedNutrition {
                    VStack(spacing: 16) {
                        // Large calorie display
                        VStack(spacing: 4) {
                            Text("\(Int(nutrition.caloriesPer100g))")
                                .font(.system(size: 48, weight: .bold))
                            Text("Calories")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Macros
                        HStack(spacing: 20) {
                            MacroColumn(label: "Total Fat", value: nutrition.fatPer100g, unit: "g")
                            Divider()
                            MacroColumn(label: "Total Carbs", value: nutrition.carbsPer100g, unit: "g")
                            Divider()
                            MacroColumn(label: "Protein", value: nutrition.proteinPer100g, unit: "g")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                
                Spacer()
                
                // Amount label
                Text("Amount")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                
                // Unified picker area - like LoseIt with 3 wheels side by side
                HStack(spacing: 0) {
                    // Whole number picker
                    Picker("Whole", selection: $wholeNumber) {
                        ForEach(0...500, id: \.self) { number in
                            Text("\(number)").tag(number)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    
                    // Fraction picker
                    Picker("Fraction", selection: $fraction) {
                        ForEach(Fraction.allCases) { frac in
                            Text(frac.displayName).tag(frac)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    
                    // Unit picker
                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(getAvailableUnits(), id: \.id) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 150)
                .background(Color(.secondarySystemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add to \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addToMeal()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func getAvailableUnits() -> [ServingUnit] {
        var units: [ServingUnit] = []
        
        // Always include weight units
        units.append(.gram)
        units.append(.ounce)
        
        // Add volume units for liquids and semi-liquids
        if foodType == .liquid || foodType == .milk || foodType == .peanutButter || foodType == .honey || foodType == .oil {
            units.append(contentsOf: [.cup, .fluidOunce, .tablespoon, .teaspoon])
        }
        
        // Add serving if product has one
        if productServingGrams != nil {
            units.insert(.serving, at: 0)
        }
        
        return units
    }
    
    private func addToMeal() {
        guard let per100gNutrition = nutritionPer100g else { return }
        
        // If we have an existing FoodItem, reuse it to preserve original serving description
        let foodItem: FoodItem
        if let existing = existingFoodItem {
            foodItem = existing
        } else {
            // Create new FoodItem for API results
            let gramsPerSingleUnit: Double
            if selectedUnit == .serving, let servingGrams = productServingGrams {
                // Use the actual serving size from the product
                gramsPerSingleUnit = servingGrams
            } else {
                // Calculate from unit conversion
                let density = ServingUnit.densityFor(foodType: foodType)
                gramsPerSingleUnit = selectedUnit.toGrams(amount: 1.0, density: density)
            }
            
            foodItem = FoodItem(
                name: product.displayName,
                brand: product.brands,
                barcode: product.code,
                nutritionPer100g: per100gNutrition,
                servingSize: gramsPerSingleUnit,
                servingSizeUnit: selectedUnit.abbreviation,
                source: "OpenFoodFacts",
                imageURL: product.imageUrl
            )
        }
        
        let addedItem = AddedFoodItem(
            foodItem: foodItem,
            servings: amountValue,
            totalGrams: totalGrams
        )
        
        onAdd(addedItem)
    }
}

// MARK: - Supporting Views

struct MacroColumn: View {
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let sampleProduct = ProductInfo(
        code: "123456",
        productName: "Peanut Butter",
        brands: "Jif",
        imageUrl: nil,
        nutriments: Nutriments(
            energyKcal100g: FlexibleDouble(588),
            energyKcalComputed: 588,
            proteins100g: FlexibleDouble(25),
            carbohydrates100g: FlexibleDouble(20),
            sugars100g: FlexibleDouble(10),
            fat100g: FlexibleDouble(50),
            saturatedFat100g: FlexibleDouble(10),
            transFat100g: nil,
            monounsaturatedFat100g: nil,
            polyunsaturatedFat100g: nil,
            fiber100g: FlexibleDouble(6),
            sodium100g: FlexibleDouble(0.45),
            salt100g: FlexibleDouble(1.1),
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
        ),
        servingSize: "2 tbsp (32g)",
        quantity: nil
    )
    
    ImprovedServingPicker(product: sampleProduct, mealType: .breakfast) { _ in }
}
