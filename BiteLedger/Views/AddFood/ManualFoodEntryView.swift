import SwiftUI
import SwiftData

/// Manual food entry for when barcode/search fails or user wants custom entry
struct ManualFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mealType: MealType
    let onAdd: (AddedFoodItem) -> Void
    
    @State private var foodName = ""
    @State private var brand = ""
    @State private var servingDescription = "1 serving"
    @State private var servingWeight = "" // Weight in grams
    @State private var servingVolume = "" // Volume if applicable
    
    // Amount to add
    @State private var amountToAdd = "1"
    
    // Nutrition Facts (per serving)
    @State private var calories = ""
    @State private var totalFat = ""
    @State private var saturatedFat = ""
    @State private var transFat = ""
    @State private var cholesterol = ""
    @State private var sodium = ""
    @State private var totalCarbs = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var protein = ""
    
    // Vitamins & Minerals
    @State private var vitaminA = ""
    @State private var vitaminC = ""
    @State private var vitaminD = ""
    @State private var calcium = ""
    @State private var iron = ""
    @State private var potassium = ""
    
    @State private var showingServingSizePicker = false
    @State private var showingAmountPicker = false
    @State private var showingScanner = false
    
    private var isValid: Bool {
        !foodName.isEmpty && !calories.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Food Name (e.g., Salad)", text: $foodName)
                    TextField("Brand (e.g., McDonald's)", text: $brand)
                }
                
                Section {
                    NavigationLink {
                        ServingSizeEditorView(
                            servingDescription: $servingDescription,
                            servingWeight: $servingWeight,
                            servingVolume: $servingVolume
                        )
                    } label: {
                        HStack {
                            Text("Serving Size")
                            Spacer()
                            Text(servingDescription)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        AmountPickerView(amount: $amountToAdd)
                    } label: {
                        HStack {
                            Text("Amount to Add")
                            Spacer()
                            Text(amountToAdd.isEmpty ? "None" : amountToAdd)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Serving Information")
                }
                
                // Camera feature
                Section {
                    Button {
                        showingScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(.orange)
                            Text("Autofill with your Camera")
                                .foregroundStyle(.orange)
                        }
                    }
                } footer: {
                    Text("Scan a nutrition label to quickly fill in values")
                        .font(.caption)
                }
                
                // Nutrition Facts - FDA label order
                Section {
                    ManualNutritionRow(label: "Calories", value: $calories, unit: "")
                        .fontWeight(.medium)
                } header: {
                    Text("Nutrition Facts")
                } footer: {
                    Text("Enter nutrition values per serving (\(servingDescription))")
                        .font(.caption)
                }
                
                Section("Fats") {
                    ManualNutritionRow(label: "Total Fat", value: $totalFat, unit: "g")
                    ManualNutritionRow(label: "  Saturated Fat", value: $saturatedFat, unit: "g", isIndented: true)
                    ManualNutritionRow(label: "  Trans Fat", value: $transFat, unit: "g", isIndented: true)
                }
                
                Section("Other Nutrients") {
                    ManualNutritionRow(label: "Cholesterol", value: $cholesterol, unit: "mg")
                    ManualNutritionRow(label: "Sodium", value: $sodium, unit: "mg")
                }
                
                Section("Carbohydrates") {
                    ManualNutritionRow(label: "Total Carbohydrate", value: $totalCarbs, unit: "g")
                    ManualNutritionRow(label: "  Dietary Fiber", value: $fiber, unit: "g", isIndented: true)
                    ManualNutritionRow(label: "  Total Sugars", value: $sugar, unit: "g", isIndented: true)
                }
                
                Section("Protein") {
                    ManualNutritionRow(label: "Protein", value: $protein, unit: "g")
                }
                
                Section("Vitamins & Minerals (Optional)") {
                    ManualNutritionRow(label: "Vitamin A", value: $vitaminA, unit: "μg")
                    ManualNutritionRow(label: "Vitamin C", value: $vitaminC, unit: "mg")
                    ManualNutritionRow(label: "Vitamin D", value: $vitaminD, unit: "μg")
                    ManualNutritionRow(label: "Calcium", value: $calcium, unit: "mg")
                    ManualNutritionRow(label: "Iron", value: $iron, unit: "mg")
                    ManualNutritionRow(label: "Potassium", value: $potassium, unit: "mg")
                }
            }
            .navigationTitle("New Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addManualFood()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(isValid ? .orange : .gray)
                    }
                    .disabled(!isValid)
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                NutritionLabelScannerView { nutritionData in
                    populateFromScan(nutritionData)
                }
            }
        }
    }
    
    private func populateFromScan(_ data: NutritionData) {
        // Fill in serving size if detected
        if let servingSize = data.servingSize {
            servingDescription = servingSize
        }
        
        // Fill in nutrition values
        if let cal = data.calories {
            calories = String(format: "%.0f", cal)
        }
        if let fat = data.totalFat {
            totalFat = String(format: "%.1f", fat)
        }
        if let satFat = data.saturatedFat {
            saturatedFat = String(format: "%.1f", satFat)
        }
        if let trans = data.transFat {
            transFat = String(format: "%.1f", trans)
        }
        if let chol = data.cholesterol {
            cholesterol = String(format: "%.0f", chol)
        }
        if let sod = data.sodium {
            sodium = String(format: "%.0f", sod)
        }
        if let carbs = data.totalCarbs {
            totalCarbs = String(format: "%.1f", carbs)
        }
        if let fib = data.fiber {
            fiber = String(format: "%.1f", fib)
        }
        if let sug = data.sugars {
            sugar = String(format: "%.1f", sug)
        }
        if let prot = data.protein {
            protein = String(format: "%.1f", prot)
        }
        if let vitD = data.vitaminD {
            vitaminD = String(format: "%.1f", vitD)
        }
        if let calc = data.calcium {
            calcium = String(format: "%.0f", calc)
        }
        if let fe = data.iron {
            iron = String(format: "%.1f", fe)
        }
        if let pot = data.potassium {
            potassium = String(format: "%.0f", pot)
        }
    }
    
    private func addManualFood() {
        guard let caloriesVal = Double(calories) else { return }
        
        // Get optional nutrition values (entered per serving)
        let proteinVal = Double(protein) ?? 0
        let carbsVal = Double(totalCarbs) ?? 0
        let fatVal = Double(totalFat) ?? 0
        
        // Get the actual grams per serving if provided, otherwise estimate as 1g
        let actualGramsPerServing = Double(servingWeight) ?? 1.0
        
        // Calculate the divisor to convert from per-serving to per-100g
        let per100gDivisor = actualGramsPerServing / 100.0
        
        // Helper to convert mg to g for storage
        let mgToG: (String) -> Double? = { str in
            guard !str.isEmpty, let val = Double(str) else { return nil }
            return val / 1000.0
        }
        
        let ugToG: (String) -> Double? = { str in
            guard !str.isEmpty, let val = Double(str) else { return nil }
            return val / 1_000_000.0
        }
        
        // Convert all per-serving values to per-100g for internal storage
        let foodItem = FoodItem(
            name: foodName,
            brand: brand.isEmpty ? nil : brand,
            caloriesPer100g: caloriesVal / per100gDivisor,
            proteinPer100g: proteinVal / per100gDivisor,
            carbsPer100g: carbsVal / per100gDivisor,
            fatPer100g: fatVal / per100gDivisor,
            fiberPer100g: fiber.isEmpty ? nil : (Double(fiber)! / per100gDivisor),
            sugarPer100g: sugar.isEmpty ? nil : (Double(sugar)! / per100gDivisor),
            sodiumPer100g: mgToG(sodium).map { $0 / per100gDivisor },
            saturatedFatPer100g: saturatedFat.isEmpty ? nil : (Double(saturatedFat)! / per100gDivisor),
            transFatPer100g: transFat.isEmpty ? nil : (Double(transFat)! / per100gDivisor),
            monounsaturatedFatPer100g: nil,
            polyunsaturatedFatPer100g: nil,
            cholesterolPer100g: mgToG(cholesterol).map { $0 / per100gDivisor },
            vitaminAPer100g: ugToG(vitaminA).map { $0 / per100gDivisor },
            vitaminCPer100g: mgToG(vitaminC).map { $0 / per100gDivisor },
            vitaminDPer100g: ugToG(vitaminD).map { $0 / per100gDivisor },
            calciumPer100g: mgToG(calcium).map { $0 / per100gDivisor },
            ironPer100g: mgToG(iron).map { $0 / per100gDivisor },
            potassiumPer100g: mgToG(potassium).map { $0 / per100gDivisor },
            servingDescription: servingDescription,
            gramsPerServing: actualGramsPerServing,
            servingSizeIsEstimated: servingWeight.isEmpty,
            source: "Manual"
        )
        
        let amount = Double(amountToAdd) ?? 1.0
        let totalGrams = amount * actualGramsPerServing
        
        let addedItem = AddedFoodItem(
            foodItem: foodItem,
            servings: amount,
            totalGrams: totalGrams
        )
        
        onAdd(addedItem)
        dismiss()
    }
}

// MARK: - Supporting Views

struct ManualNutritionRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    var isIndented: Bool = false
    
    var body: some View {
        HStack {
            if isIndented {
                Text(label)
                    .font(.subheadline)
            } else {
                Text(label)
            }
            
            Spacer()
            
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            
            if !unit.isEmpty {
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
}

struct ServingSizeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var servingDescription: String
    @Binding var servingWeight: String
    @Binding var servingVolume: String
    
    var body: some View {
        Form {
            Section {
                TextField("e.g., 1 cup, 2 tbsp, 1 banana", text: $servingDescription)
            } header: {
                Text("Serving Description")
            } footer: {
                Text("Describe one serving (e.g., \"1 cup\", \"2 slices\", \"1 medium banana\")")
            }
            
            Section {
                HStack {
                    TextField("Optional", text: $servingWeight)
                        .keyboardType(.decimalPad)
                    Text("g")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Serving Weight")
            } footer: {
                Text("Enter the weight in grams for one serving (optional)")
            }
            
            Section {
                HStack {
                    TextField("Optional", text: $servingVolume)
                        .keyboardType(.decimalPad)
                    Text("mL")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Serving Volume")
            } footer: {
                Text("Enter the volume in mL for one serving (optional)")
            }
        }
        .navigationTitle("Serving Size")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

struct AmountPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var amount: String
    
    @State private var wholeNumber: Int = 1
    @State private var fraction: Fraction = .zero
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Select Amount")
                .font(.headline)
                .padding()
            
            HStack(spacing: 0) {
                Picker("Whole", selection: $wholeNumber) {
                    ForEach(0...100, id: \.self) { number in
                        Text("\(number)").tag(number)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                
                Picker("Fraction", selection: $fraction) {
                    ForEach(Fraction.allCases) { frac in
                        Text(frac.displayName).tag(frac)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
            }
            .frame(height: 200)
            
            Button {
                let total = Double(wholeNumber) + fraction.rawValue
                amount = String(format: "%.2f", total).replacingOccurrences(of: ".00", with: "")
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            if let val = Double(amount) {
                wholeNumber = Int(val)
                let fractionalPart = val - Double(wholeNumber)
                fraction = Fraction.allCases.min(by: {
                    abs($0.rawValue - fractionalPart) < abs($1.rawValue - fractionalPart)
                }) ?? .zero
            }
        }
    }
}

#Preview {
    ManualFoodEntryView(mealType: .breakfast) { _ in }
}
