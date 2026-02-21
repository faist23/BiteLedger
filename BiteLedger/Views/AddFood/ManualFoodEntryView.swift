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
    @State private var portions: [CustomPortion] = []
    @State private var showingPortionEditor = false
    @State private var selectedNutritionPortion: CustomPortion?  // Which portion the nutrition is for
    
    private var isValid: Bool {
        !foodName.isEmpty && !calories.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Food Name (e.g., Salad)", text: $foodName)
                        .textInputAutocapitalization(.words)
                    TextField("Brand (e.g., McDonald's)", text: $brand)
                        .textInputAutocapitalization(.words)
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
                } footer: {
                    if !portions.isEmpty {
                        Text("This is your reference size for entering nutrition facts below.")
                            .font(.caption)
                    }
                }
                
                // Portion sizes (optional)
                Section {
                    if portions.isEmpty {
                        // Quick add common sizes
                        VStack(spacing: 12) {
                            Text("Quick Add Common Sizes:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Button("Small + Medium + Large") {
                                    showingPortionEditor = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(portions) { portion in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(portion.name.capitalized)
                                            .font(.body)
                                            .fontWeight(selectedNutritionPortion?.id == portion.id ? .semibold : .regular)
                                        if selectedNutritionPortion?.id == portion.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.caption)
                                        }
                                    }
                                    if selectedNutritionPortion?.id == portion.id {
                                        Text("Nutrition reference")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("Tap to use as reference")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(portion.displayText)
                                        .foregroundStyle(.primary)
                                    Text("(\(Int(portion.grams))g)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(selectedNutritionPortion?.id == portion.id ? 
                                       Color.green.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedNutritionPortion?.id == portion.id ? 
                                           Color.green : Color.clear, lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNutritionPortion = portion
                                servingDescription = "1 \(portion.name)"
                                servingWeight = String(Int(portion.grams))
                            }
                        }
                        .onDelete { indexSet in
                            portions.remove(atOffsets: indexSet)
                            if portions.isEmpty {
                                selectedNutritionPortion = nil
                            }
                        }
                        
                        Button {
                            showingPortionEditor = true
                        } label: {
                            Label("Add Another Size", systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text("Portion Sizes (Optional)")
                } footer: {
                    if portions.isEmpty {
                        Text("Add different sizes to make logging easier. Tap a size above to set it as your nutrition reference.")
                            .font(.caption)
                    } else if selectedNutritionPortion == nil {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("⚠️ Tap a portion (e.g., Medium) to set it as your nutrition reference before entering values below.")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    } else {
                        Text("✓ Nutrition values below are for: \(selectedNutritionPortion!.name.capitalized). Other sizes will be automatically calculated.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                // Autofill options
                Section {
                    Button {
                        showingScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(.orange)
                            Text("Scan Nutrition Label")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    NavigationLink {
                        WebsiteImportView { nutritionData in
                            populateFromScan(nutritionData)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Import from Website URL")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    NavigationLink {
                        PasteTextImportView { nutritionData in
                            populateFromScan(nutritionData)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.clipboard.fill")
                                .foregroundStyle(.green)
                            Text("Paste Nutrition Text")
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Quick Fill")
                } footer: {
                    Text("Scan a label, paste a URL, or copy nutrition text from a website popup")
                        .font(.caption)
                }
                
                // Nutrition Facts - FDA label order
                Section {
                    ManualNutritionRow(label: "Calories", value: $calories, unit: "")
                        .fontWeight(.medium)
                } header: {
                    Text("Nutrition Facts")
                } footer: {
                    if !portions.isEmpty {
                        Text("Enter nutrition values for: \(servingDescription). The app will automatically calculate nutrition for your portion sizes (Small, Medium, Large) based on their weights.")
                            .font(.caption)
                    } else {
                        Text("Enter nutrition values per serving (\(servingDescription))")
                            .font(.caption)
                    }
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
            .sheet(isPresented: $showingPortionEditor) {
                PortionEditorView { portion in
                    portions.append(portion)
                }
            }
        }
    }
    
    private func populateFromScan(_ data: NutritionData) {
        // Fill in serving size if detected
        if let servingSize = data.servingSize {
            servingDescription = servingSize
        }
        
        // Fill in serving weight if detected from serving size
        if let grams = data.servingSizeGrams {
            servingWeight = String(format: "%.0f", grams)
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
        
        // Add portions if any were defined
        if !portions.isEmpty {
            foodItem.portions = portions.map { portion in
                StoredPortion(
                    id: portion.id,
                    amount: 1.0,
                    modifier: portion.name,
                    gramWeight: portion.grams
                )
            }
        }
        
        let amount = Double(amountToAdd) ?? 1.0
        let totalGrams = amount * actualGramsPerServing
        
        let addedItem = AddedFoodItem(
            foodItem: foodItem,
            servings: amount,
            totalGrams: totalGrams,
            selectedPortionId: nil  // Manual entries don't have USDA portions
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

// MARK: - Custom Portion

struct CustomPortion: Identifiable {
    let id: Int
    let name: String
    let amount: Double
    let unit: String
    let grams: Double  // Converted value for storage
    
    init(name: String, amount: Double, unit: String, grams: Double) {
        self.id = Int.random(in: 0..<Int.max)
        self.name = name
        self.amount = amount
        self.unit = unit
        self.grams = grams
    }
    
    var displayText: String {
        if amount == 1.0 {
            return unit
        }
        let amountStr = amount.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(amount)) : String(format: "%.1f", amount)
        return "\(amountStr) \(unit)"
    }
}

// MARK: - Portion Editor View

struct PortionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (CustomPortion) -> Void
    
    enum EditorMode {
        case single
        case multipleCommon
    }
    
    @State private var editorMode: EditorMode = .multipleCommon
    
    // Single portion mode
    @State private var portionName = ""
    @State private var portionAmount = ""
    @State private var selectedUnit: ServingUnit = .fluidOunce
    
    // Multiple portions mode
    @State private var smallAmount = ""
    @State private var mediumAmount = ""
    @State private var largeAmount = ""
    @State private var commonUnit: ServingUnit = .fluidOunce
    
    // Common units for portions
    private let availableUnits: [ServingUnit] = [
        .fluidOunce, .ounce, .gram, .cup, .milliliter, .tablespoon, .teaspoon
    ]
    
    private func calculateGrams(amount: String, unit: ServingUnit) -> Double? {
        guard let amt = Double(amount) else { return nil }
        
        if unit == .gram {
            return amt
        } else {
            let density = 1.0  // Standard density for liquids
            return unit.toGrams(amount: amt, density: density)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Mode picker
                Section {
                    Picker("Add", selection: $editorMode) {
                        Text("Small, Medium, Large").tag(EditorMode.multipleCommon)
                        Text("Single Size").tag(EditorMode.single)
                    }
                    .pickerStyle(.segmented)
                }
                
                if editorMode == .multipleCommon {
                    // Quick add Small, Medium, Large
                    Section {
                        Picker("Unit", selection: $commonUnit) {
                            ForEach(availableUnits, id: \.id) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        
                        HStack {
                            Text("Small")
                                .frame(width: 70, alignment: .leading)
                            TextField("Amount", text: $smallAmount)
                                .keyboardType(.decimalPad)
                            if let grams = calculateGrams(amount: smallAmount, unit: commonUnit) {
                                Text("(\(Int(grams))g)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("Medium")
                                .frame(width: 70, alignment: .leading)
                            TextField("Amount", text: $mediumAmount)
                                .keyboardType(.decimalPad)
                            if let grams = calculateGrams(amount: mediumAmount, unit: commonUnit) {
                                Text("(\(Int(grams))g)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("Large")
                                .frame(width: 70, alignment: .leading)
                            TextField("Amount", text: $largeAmount)
                                .keyboardType(.decimalPad)
                            if let grams = calculateGrams(amount: largeAmount, unit: commonUnit) {
                                Text("(\(Int(grams))g)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Portion Sizes")
                    } footer: {
                        Text("Enter amounts for each size. Example: 12, 20, 24 for fl oz")
                            .font(.caption)
                    }
                } else {
                    // Single portion entry
                    Section {
                        TextField("Name (e.g., Tall, Grande, Venti)", text: $portionName)
                    } header: {
                        Text("Portion Name")
                    }
                    
                    Section {
                        HStack {
                            TextField("Amount", text: $portionAmount)
                                .keyboardType(.decimalPad)
                            
                            Picker("Unit", selection: $selectedUnit) {
                                ForEach(availableUnits, id: \.id) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        if let grams = calculateGrams(amount: portionAmount, unit: selectedUnit) {
                            HStack {
                                Text("Equivalent Weight")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(grams))g")
                                    .foregroundStyle(.blue)
                            }
                        }
                    } header: {
                        Text("Portion Size")
                    }
                }
            }
            .navigationTitle("Add Portions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if editorMode == .multipleCommon {
                            // Add Small, Medium, Large
                            if let smallGrams = calculateGrams(amount: smallAmount, unit: commonUnit),
                               let small = Double(smallAmount) {
                                onAdd(CustomPortion(name: "small", amount: small, unit: commonUnit.rawValue, grams: smallGrams))
                            }
                            if let mediumGrams = calculateGrams(amount: mediumAmount, unit: commonUnit),
                               let medium = Double(mediumAmount) {
                                onAdd(CustomPortion(name: "medium", amount: medium, unit: commonUnit.rawValue, grams: mediumGrams))
                            }
                            if let largeGrams = calculateGrams(amount: largeAmount, unit: commonUnit),
                               let large = Double(largeAmount) {
                                onAdd(CustomPortion(name: "large", amount: large, unit: commonUnit.rawValue, grams: largeGrams))
                            }
                        } else {
                            // Add single portion
                            if let amount = Double(portionAmount),
                               let grams = calculateGrams(amount: portionAmount, unit: selectedUnit),
                               !portionName.isEmpty {
                                onAdd(CustomPortion(name: portionName, amount: amount, unit: selectedUnit.rawValue, grams: grams))
                            }
                        }
                        dismiss()
                    }
                    .disabled(editorMode == .multipleCommon ? 
                             (smallAmount.isEmpty && mediumAmount.isEmpty && largeAmount.isEmpty) :
                             (portionName.isEmpty || portionAmount.isEmpty))
                }
            }
        }
    }
}

// MARK: - Website Import View

struct WebsiteImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onImport: (NutritionData) -> Void
    
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section {
                TextField("Paste website URL", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("Website URL")
            } footer: {
                Text("Paste a link from a restaurant nutrition page (e.g., Tim Hortons, McDonald's)")
                    .font(.caption)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button {
                    Task {
                        await fetchNutrition()
                    }
                } label: {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Fetching...")
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("Import Nutrition")
                            Spacer()
                        }
                    }
                }
                .disabled(urlText.isEmpty || isLoading)
            }
        }
        .navigationTitle("Import from Website")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func fetchNutrition() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: urlText) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                errorMessage = "Could not read webpage"
                isLoading = false
                return
            }
            
            // Try to parse nutrition from HTML
            if let nutritionData = parseNutritionFromHTML(html) {
                await MainActor.run {
                    onImport(nutritionData)
                    dismiss()
                }
            } else {
                errorMessage = "Could not find nutrition information on this page"
            }
        } catch {
            errorMessage = "Error fetching page: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func parseNutritionFromHTML(_ html: String) -> NutritionData? {
        // Simple regex-based parsing for common patterns
        var nutritionData = NutritionData()
        
        // Calories - match patterns like "Calories 2961 kcal" or "Calories: 296"
        if let caloriesMatch = html.range(of: #"(?i)calories[\s:]+(\d+(?:\.\d+)?)"#, options: .regularExpression) {
            let caloriesStr = String(html[caloriesMatch])
            if let value = extractNumber(from: caloriesStr) {
                nutritionData.calories = value
            }
        }
        
        // Fat - match "Fat 17.4 g" or "Total Fat: 17g"
        if let fatMatch = html.range(of: #"(?i)(?:total\s)?fat[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression) {
            let fatStr = String(html[fatMatch])
            if let value = extractNumber(from: fatStr) {
                nutritionData.totalFat = value
            }
        }
        
        // Saturated Fat
        if let satFatMatch = html.range(of: #"(?i)saturated\s+fat[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression) {
            let satFatStr = String(html[satFatMatch])
            if let value = extractNumber(from: satFatStr) {
                nutritionData.saturatedFat = value
            }
        }
        
        // Trans Fat
        if let transFatMatch = html.range(of: #"(?i)trans\s+fat[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression) {
            let transFatStr = String(html[transFatMatch])
            if let value = extractNumber(from: transFatStr) {
                nutritionData.transFat = value
            }
        }
        
        // Cholesterol - match "Cholesterol 55.1 mg"
        if let cholMatch = html.range(of: #"(?i)cholesterol[\s:]+(\d+(?:\.\d+)?)\s*mg"#, options: .regularExpression) {
            let cholStr = String(html[cholMatch])
            if let value = extractNumber(from: cholStr) {
                nutritionData.cholesterol = value
            }
        }
        
        // Sodium - match "Sodium 814 mg"
        if let sodiumMatch = html.range(of: #"(?i)sodium[\s:]+(\d+(?:\.\d+)?)\s*mg"#, options: .regularExpression) {
            let sodiumStr = String(html[sodiumMatch])
            if let value = extractNumber(from: sodiumStr) {
                nutritionData.sodium = value
            }
        }
        
        // Carbohydrates - match "Carbohydrates 30.7 g"
        if let carbsMatch = html.range(of: #"(?i)(?:total\s)?carbohydrate(?:s)?[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression) {
            let carbsStr = String(html[carbsMatch])
            if let value = extractNumber(from: carbsStr) {
                nutritionData.totalCarbs = value
            }
        }
        
        // Fiber - match "Fiber 0.6 g"
        if let fiberMatch = html.range(of: #"(?i)(?:dietary\s)?fiber[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression) {
            let fiberStr = String(html[fiberMatch])
            if let value = extractNumber(from: fiberStr) {
                nutritionData.fiber = value
            }
        }
        
        // Sugar - match "Sugar 28.6 g"
        if let sugarMatch = html.range(of: #"(?i)(?:total\s)?sugar(?:s)?[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression) {
            let sugarStr = String(html[sugarMatch])
            if let value = extractNumber(from: sugarStr) {
                nutritionData.sugars = value
            }
        }
        
        // Protein - match "Protein 3.2 g" or "Proteins 3.2 g"
        if let proteinMatch = html.range(of: #"(?i)proteins?[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression) {
            let proteinStr = String(html[proteinMatch])
            if let value = extractNumber(from: proteinStr) {
                nutritionData.protein = value
            }
        }
        
        // Only return if we found at least calories
        return nutritionData.calories != nil ? nutritionData : nil
    }
    
    private func extractNumber(from text: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return Double(String(text[range]))
    }
}

// MARK: - Paste Text Import View

struct PasteTextImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onImport: (NutritionData) -> Void
    
    @State private var pastedText = ""
    
    var body: some View {
        Form {
            Section {
                TextEditor(text: $pastedText)
                    .frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Nutrition Text")
            } footer: {
                Text("Copy nutrition info from a website popup (e.g., Tim Hortons) and paste here")
                    .font(.caption)
            }
            
            Section {
                Button {
                    if let nutritionData = parseNutritionFromText(pastedText) {
                        onImport(nutritionData)
                        dismiss()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Import Nutrition")
                        Spacer()
                    }
                }
                .disabled(pastedText.isEmpty)
            }
        }
        .navigationTitle("Paste Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") {
                    pastedText = ""
                }
                .disabled(pastedText.isEmpty)
            }
        }
    }
    
    private func parseNutritionFromText(_ text: String) -> NutritionData? {
        var nutritionData = NutritionData()
        
        // Normalize text - remove extra whitespace, newlines
        let normalizedText = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Calories - match patterns like "Calories 2961 kcal" or "Calories: 296" or "2961 kcal"
        let caloriesPatterns = [
            #"(?i)calories[\s:]+(\d+(?:\.\d+)?)"#,
            #"(\d+(?:\.\d+)?)\s*kcal"#
        ]
        for pattern in caloriesPatterns {
            if let match = normalizedText.range(of: pattern, options: .regularExpression),
               let value = extractNumber(from: String(normalizedText[match])) {
                nutritionData.calories = value
                break
            }
        }
        
        // Fat - match "Fat 17.4 g" or "17.4 g" (if near "Fat" keyword)
        if let fatMatch = normalizedText.range(of: #"(?i)(?:total\s)?fat[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[fatMatch])) {
            nutritionData.totalFat = value
        }
        
        // Saturated Fat
        if let satFatMatch = normalizedText.range(of: #"(?i)saturated\s+fat[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[satFatMatch])) {
            nutritionData.saturatedFat = value
        }
        
        // Trans Fat
        if let transFatMatch = normalizedText.range(of: #"(?i)trans\s+fat[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[transFatMatch])) {
            nutritionData.transFat = value
        }
        
        // Cholesterol
        if let cholMatch = normalizedText.range(of: #"(?i)cholesterol[\s:]+(\d+(?:\.\d+)?)\s*mg"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[cholMatch])) {
            nutritionData.cholesterol = value
        }
        
        // Sodium
        if let sodiumMatch = normalizedText.range(of: #"(?i)sodium[\s:]+(\d+(?:\.\d+)?)\s*mg"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[sodiumMatch])) {
            nutritionData.sodium = value
        }
        
        // Carbohydrates
        if let carbsMatch = normalizedText.range(of: #"(?i)(?:total\s)?carbohydrate(?:s)?[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[carbsMatch])) {
            nutritionData.totalCarbs = value
        }
        
        // Fiber
        if let fiberMatch = normalizedText.range(of: #"(?i)(?:dietary\s)?fiber[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[fiberMatch])) {
            nutritionData.fiber = value
        }
        
        // Sugar
        if let sugarMatch = normalizedText.range(of: #"(?i)(?:total\s)?sugar(?:s)?[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[sugarMatch])) {
            nutritionData.sugars = value
        }
        
        // Protein (handles both "Protein" and "Proteins")
        if let proteinMatch = normalizedText.range(of: #"(?i)proteins?[\s:]+(\d+(?:\.\d+)?)\s*g"#, options: .regularExpression),
           let value = extractNumber(from: String(normalizedText[proteinMatch])) {
            nutritionData.protein = value
        }
        
        // Only return if we found at least calories
        return nutritionData.calories != nil ? nutritionData : nil
    }
    
    private func extractNumber(from text: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return Double(String(text[range]))
    }
}

#Preview {
    ManualFoodEntryView(mealType: .breakfast) { _ in }
}
