import SwiftUI
import SwiftData

/// Quick serving size picker - simplified for fast meal entry
struct QuickServingPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let product: ProductInfo
    let mealType: MealType
    let onAdd: (AddedFoodItem) -> Void
    
    @State private var servingAmount: Double = 1.0
    @State private var selectedUnit: ServingUnit = .gram
    @State private var customGrams: String = "100"
    
    private var servingSizeGrams: Double {
        switch selectedUnit {
        case .gram:
            return Double(customGrams) ?? 100
        case .serving:
            return parseServingSize(product.servingSize) * servingAmount
        case .container:
            return parseServingSize(product.quantity) * servingAmount
        default:
            return Double(customGrams) ?? 100
        }
    }
    
    private var nutritionMultiplier: Double {
        servingSizeGrams / 100.0
    }
    
    private var calculatedNutrition: NutritionFacts? {
        product.nutriments?.toNutritionFacts(servingMultiplier: nutritionMultiplier)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product header - compact
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            if let imageUrl = product.imageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 60, height: 60)
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
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    
                    // Serving size picker - streamlined
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How much?")
                            .font(.headline)
                        
                        Picker("Unit", selection: $selectedUnit) {
                            Text("Grams").tag(ServingUnit.gram)
                            if product.servingSize != nil {
                                Text("Serving").tag(ServingUnit.serving)
                            }
                            if product.quantity != nil {
                                Text("Container").tag(ServingUnit.container)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        switch selectedUnit {
                        case .gram:
                            HStack {
                                TextField("Amount", text: $customGrams)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                
                                Text("grams")
                                    .foregroundStyle(.secondary)
                            }
                            
                        case .serving:
                            VStack(spacing: 8) {
                                Stepper(value: $servingAmount, in: 0.25...20, step: 0.25) {
                                    HStack {
                                        Text("\(servingAmount, specifier: "%.2f")")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Text("servings")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                if let servingSize = product.servingSize {
                                    Text("1 serving = \(servingSize)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                        case .container:
                            VStack(spacing: 8) {
                                Stepper(value: $servingAmount, in: 0.25...20, step: 0.25) {
                                    HStack {
                                        Text("\(servingAmount, specifier: "%.2f")")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Text("containers")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                if let quantity = product.quantity {
                                    Text("1 container = \(quantity)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        
                        default:
                            // For all other units, use gram input
                            HStack {
                                TextField("Amount", text: $customGrams)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                
                                Text(selectedUnit.abbreviation)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    
                    // Nutrition summary - compact
                    if let nutrition = calculatedNutrition {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Nutrition")
                                    .font(.headline)
                                Spacer()
                                Text("\(servingSizeGrams, specifier: "%.0f")g")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Macros in a grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                MacroCard(label: "Calories", value: nutrition.caloriesPer100g, unit: "kcal", color: .red)
                                MacroCard(label: "Protein", value: nutrition.proteinPer100g, unit: "g", color: .blue)
                                MacroCard(label: "Carbs", value: nutrition.carbsPer100g, unit: "g", color: .orange)
                                MacroCard(label: "Fat", value: nutrition.fatPer100g, unit: "g", color: .purple)
                            }
                        }
                        .padding()
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
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
                    .disabled(calculatedNutrition == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func addToMeal() {
        guard let nutrition = calculatedNutrition else { return }
        
        // Create FoodItem
        let foodItem = FoodItem(
            name: product.displayName,
            brand: product.brands,
            barcode: product.code,
            nutritionPer100g: nutrition,
            servingSize: servingSizeGrams,
            servingSizeUnit: selectedUnit.abbreviation,
            source: "OpenFoodFacts",
            imageURL: product.imageUrl
        )
        
        // Create added item
        let addedItem = AddedFoodItem(
            foodItem: foodItem,
            servings: servingAmount,
            totalGrams: servingSizeGrams
        )
        
        onAdd(addedItem)
    }
    
    private func parseServingSize(_ sizeString: String?) -> Double {
        guard let sizeString = sizeString else { return 100 }
        
        let numericString = sizeString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(numericString) ?? 100
    }
}

// MARK: - Supporting Views

struct MacroCard: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(value, specifier: "%.0f")")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let sampleProduct = ProductInfo(
        code: "123456789",
        productName: "Organic Honey",
        brands: "Nature's Best",
        imageUrl: nil,
        nutriments: Nutriments(
            energyKcal100g: FlexibleDouble(304),
            energyKcalComputed: 304,
            proteins100g: FlexibleDouble(0.3),
            carbohydrates100g: FlexibleDouble(82),
            sugars100g: FlexibleDouble(82),
            fat100g: FlexibleDouble(0),
            saturatedFat100g: FlexibleDouble(0),
            transFat100g: nil,
            monounsaturatedFat100g: nil,
            polyunsaturatedFat100g: nil,
            fiber100g: FlexibleDouble(0.2),
            sodium100g: FlexibleDouble(0.004),
            salt100g: FlexibleDouble(0.01),
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
        servingSize: "21g",
        quantity: "340g"
    )
    
    QuickServingPicker(product: sampleProduct, mealType: .breakfast) { _ in }
        .modelContainer(for: FoodLog.self, inMemory: true)
}
