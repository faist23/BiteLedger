import SwiftUI
import SwiftData

/// View for displaying product details and selecting serving size
struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let product: ProductInfo
    
    @State private var servingAmount: Double = 1.0
    @State private var selectedUnit: ServingUnit = .gram
    @State private var customGrams: String = "100"
    @State private var selectedMealType: MealType = .breakfast
    @State private var showingSuccessAlert = false
    
    private var servingSizeGrams: Double {
        switch selectedUnit {
        case .gram:
            return Double(customGrams) ?? 100
        case .serving:
            // Parse serving size from product (e.g., "30g" -> 30)
            return parseServingSize(product.servingSize) * servingAmount
        case .container:
            // Parse quantity from product (e.g., "250g" -> 250)
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
                    // Product header
                    VStack(alignment: .leading, spacing: 8) {
                        if let imageUrl = product.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.quaternary)
                                    .frame(height: 200)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        }
                        
                        Text(product.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(product.displayBrand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let servingSize = product.servingSize {
                            Label("Serving: \(servingSize)", systemImage: "scalemass")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    
                    // Serving size picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Serving Size")
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
                            HStack {
                                Text("Amount:")
                                    .foregroundStyle(.secondary)
                                
                                Stepper(value: $servingAmount, in: 0.25...20, step: 0.25) {
                                    Text("\(servingAmount, specifier: "%.2f") servings")
                                        .font(.headline)
                                }
                            }
                            
                            if let servingSize = product.servingSize {
                                Text("1 serving = \(servingSize)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                        case .container:
                            HStack {
                                Text("Amount:")
                                    .foregroundStyle(.secondary)
                                
                                Stepper(value: $servingAmount, in: 0.25...20, step: 0.25) {
                                    Text("\(servingAmount, specifier: "%.2f") containers")
                                        .font(.headline)
                                }
                            }
                            
                            if let quantity = product.quantity {
                                Text("1 container = \(quantity)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        
                        default:
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
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    
                    // Meal type picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meal Type")
                            .font(.headline)
                        
                        Picker("Meal Type", selection: $selectedMealType) {
                            ForEach(MealType.allCases, id: \.self) { type in
                                Label(type.rawValue.capitalized, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    
                    // Nutrition summary
                    if let nutrition = calculatedNutrition {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nutrition Facts")
                                .font(.headline)
                            
                            Text("For \(servingSizeGrams, specifier: "%.0f")g")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            VStack(spacing: 8) {
                                NutritionRow(label: "Calories", value: nutrition.caloriesPer100g, unit: "kcal")
                                Divider()
                                NutritionRow(label: "Protein", value: nutrition.proteinPer100g, unit: "g")
                                NutritionRow(label: "Carbs", value: nutrition.carbsPer100g, unit: "g")
                                if let sugar = nutrition.sugarPer100g {
                                    NutritionRow(label: "  Sugar", value: sugar, unit: "g", isSubItem: true)
                                }
                                NutritionRow(label: "Fat", value: nutrition.fatPer100g, unit: "g")
                                if let fiber = nutrition.fiberPer100g {
                                    NutritionRow(label: "Fiber", value: fiber, unit: "g")
                                }
                                if let sodium = nutrition.sodiumPer100g {
                                    NutritionRow(label: "Sodium", value: sodium, unit: "mg")
                                }
                            }
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addFoodLog()
                    }
                    .disabled(calculatedNutrition == nil)
                }
            }
            .alert("Added to Log", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("\(product.displayName) added to your \(selectedMealType.rawValue) log.")
            }
        }
    }
    
    private func addFoodLog() {
        guard let nutrition = calculatedNutrition else { return }
        
        let foodItem = FoodItem(
            name: product.displayName,
            brand: product.brands,
            barcode: product.code,
            nutritionPer100g: nutrition,
            servingSize: servingSizeGrams,
            servingSizeUnit: selectedUnit.abbreviation
        )
        
        let foodLog = FoodLog(
            foodItem: foodItem,
            servings: servingAmount,
            mealType: selectedMealType,
            timestamp: Date()
        )
        
        modelContext.insert(foodLog)
        
        do {
            try modelContext.save()
            showingSuccessAlert = true
        } catch {
            print("Failed to save food log: \(error)")
        }
    }
    
    private func parseServingSize(_ sizeString: String?) -> Double {
        guard let sizeString = sizeString else { return 100 }
        
        // Extract numeric value from strings like "30g", "250ml", "1.5oz"
        let numericString = sizeString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(numericString) ?? 100
    }
}

// MARK: - Supporting Views

struct NutritionRow: View {
    let label: String
    let value: Double
    let unit: String
    var isSubItem: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(isSubItem ? .secondary : .primary)
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)")
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Models
// ServingUnit moved to Models/ServingUnit.swift



#Preview {
    let sampleProduct = ProductInfo(
        code: "123456789",
        productName: "Organic Oatmeal",
        brands: "Nature's Best",
        imageUrl: nil,
        nutriments: Nutriments(
            energyKcal100g: FlexibleDouble(350),
            energyKcalComputed: 350,
            proteins100g: FlexibleDouble(12),
            carbohydrates100g: FlexibleDouble(60),
            sugars100g: FlexibleDouble(1),
            fat100g: FlexibleDouble(6),
            saturatedFat100g: FlexibleDouble(1),
            transFat100g: nil,
            monounsaturatedFat100g: nil,
            polyunsaturatedFat100g: nil,
            fiber100g: FlexibleDouble(10),
            sodium100g: FlexibleDouble(0.01),
            salt100g: FlexibleDouble(0.025),
            cholesterol100g: nil,
            vitaminA100g: nil,
            vitaminC100g: nil,
            vitaminD100g: nil,
            calcium100g: nil,
            iron100g: nil,
            potassium100g: nil,
            energyKcalServing: FlexibleDouble(175),
            proteinsServing: FlexibleDouble(6),
            carbohydratesServing: FlexibleDouble(30),
            sugarsServing: FlexibleDouble(0.5),
            fatServing: FlexibleDouble(3),
            saturatedFatServing: FlexibleDouble(0.5),
            fiberServing: FlexibleDouble(5),
            sodiumServing: FlexibleDouble(0.005)
        ),
        servingSize: "50g",
        quantity: "500g"
    )
    
    ProductDetailView(product: sampleProduct)
        .modelContainer(for: FoodLog.self, inMemory: true)
}
