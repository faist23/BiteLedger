//
//  FoodLogEditView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData

/// Edit an existing food log entry's serving size
struct FoodLogEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let log: FoodLog
    let foodItem: FoodItem
    let onSave: (FoodLog) -> Void
    
    @State private var wholeNumber: Int
    @State private var fraction: Fraction
    @State private var selectedUnit: ServingUnit
    @State private var showingNutritionEditor = false
    
    private let foodType: FoodType
    private let parsedServingUnit: String
    private let availableUnits: [ServingUnit]
    
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
    
    init(log: FoodLog, foodItem: FoodItem, onSave: @escaping (FoodLog) -> Void) {
        self.log = log
        self.foodItem = foodItem
        self.onSave = onSave
        
        self.foodType = FoodType.infer(from: foodItem.name)
        
        // Parse serving unit display name once at init
        let parsedResult = ServingSizeParser.parse(foodItem.servingDescription)
        if let parsed = parsedResult {
            self.parsedServingUnit = parsed.unit.abbreviation.capitalized
        } else {
            self.parsedServingUnit = "Serving"
        }
        
        // Calculate available units once at init
        var units: [ServingUnit] = []
        units.append(.gram)
        units.append(.ounce)
        
        if foodType == .liquid || foodType == .milk || foodType == .peanutButter || foodType == .honey || foodType == .oil {
            units.append(contentsOf: [.cup, .fluidOunce, .tablespoon, .teaspoon])
        }
        
        if foodItem.gramsPerServing > 0 {
            units.insert(.serving, at: 0)
        }
        
        self.availableUnits = units
        
        // Initialize from current serving multiplier
        let currentAmount = log.servingMultiplier
        let whole = Int(currentAmount)
        let fractionalPart = currentAmount - Double(whole)
        let closestFraction = Fraction.allCases.min(by: { 
            abs($0.rawValue - fractionalPart) < abs($1.rawValue - fractionalPart) 
        }) ?? .zero
        
        _wholeNumber = State(initialValue: whole)
        _fraction = State(initialValue: closestFraction)
        
        // Try to parse the original serving unit from the foodItem
        if let parsed = parsedResult {
            _selectedUnit = State(initialValue: parsed.unit)
        } else {
            // Fallback to serving if we have a serving size, otherwise grams
            _selectedUnit = State(initialValue: foodItem.gramsPerServing > 0 ? .serving : .gram)
        }
    }
    
    private var amountValue: Double {
        Double(wholeNumber) + fraction.rawValue
    }
    
    private var totalGrams: Double {
        if selectedUnit == .serving {
            // For serving unit, multiply by the food's gramsPerServing
            return amountValue * foodItem.gramsPerServing
        } else {
            let density = ServingUnit.densityFor(foodType: foodType)
            return selectedUnit.toGrams(amount: amountValue, density: density)
        }
    }
    
    private var nutritionMultiplier: Double {
        totalGrams / 100.0
    }
    
    private var calculatedNutrition: NutritionFacts {
        NutritionFacts(
            caloriesPer100g: foodItem.caloriesPer100g * nutritionMultiplier,
            proteinPer100g: foodItem.proteinPer100g * nutritionMultiplier,
            carbsPer100g: foodItem.carbsPer100g * nutritionMultiplier,
            fatPer100g: foodItem.fatPer100g * nutritionMultiplier,
            fiberPer100g: (foodItem.fiberPer100g ?? 0) * nutritionMultiplier,
            sugarPer100g: (foodItem.sugarPer100g ?? 0) * nutritionMultiplier,
            sodiumPer100g: (foodItem.sodiumPer100g ?? 0) * nutritionMultiplier
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Product header
                HStack(spacing: 12) {
                    if let imageUrl = foodItem.imageURL, let url = URL(string: imageUrl) {
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
                        Text(foodItem.name)
                            .font(.headline)
                            .lineLimit(2)
                        
                        if let brand = foodItem.brand {
                            Text(brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color("SurfaceBackground"))
                
                Spacer()
                
                // Nutrition header
                HStack {
                    Text("NUTRITION FACTS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("TextSecondary"))
                    
                    Spacer()
                    
                    Button {
                        showingNutritionEditor = true
                    } label: {
                        Text("EDIT NUTRITION")
                            .font(.caption)
                            .fontWeight(.semibold)
                        .foregroundStyle(Color("BrandAccent"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                
                // Nutrition display - LoseIt style
                VStack {
                    HStack(alignment: .top, spacing: 40) {
                        // Large calorie display on left
                        VStack(spacing: 4) {
                            Text("\(Int(calculatedNutrition.caloriesPer100g))")
                                .font(.system(size: 56, weight: .bold))
                            Text("Calories")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Detailed nutrition on right
                        VStack(alignment: .leading, spacing: 4) {
                            NutritionRow(label: "Total Fat", value: calculatedNutrition.fatPer100g, unit: "g")
                            if let satFat = foodItem.saturatedFatPer100g {
                                NutritionRow(label: "  Sat Fat", value: satFat * nutritionMultiplier, unit: "g", isSubItem: true)
                            }
                            if let cholesterol = foodItem.cholesterolPer100g {
                                NutritionRow(label: "  Cholesterol", value: cholesterol * nutritionMultiplier, unit: "mg", isSubItem: true)
                            }
                            if let sodium = calculatedNutrition.sodiumPer100g {
                                NutritionRow(label: "Sodium", value: sodium, unit: "mg")
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            NutritionRow(label: "Total Carbs", value: calculatedNutrition.carbsPer100g, unit: "g")
                            if let fiber = calculatedNutrition.fiberPer100g {
                                NutritionRow(label: "  Fiber", value: fiber, unit: "g", isSubItem: true)
                            }
                            if let sugar = calculatedNutrition.sugarPer100g {
                                NutritionRow(label: "  Sugars", value: sugar, unit: "g", isSubItem: true)
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            NutritionRow(label: "Protein", value: calculatedNutrition.proteinPer100g, unit: "g")
                        }
                        .font(.caption)
                    }
                }
                .padding(24)
                .background(Color("SurfacePrimary"))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
                .padding(.horizontal)
                
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
                        ForEach(availableUnits, id: \.id) { unit in
                            Text(displayNameForUnit(unit)).tag(unit)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 150)
                .background(Color("SurfacePrimary"))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingNutritionEditor) {
                NutritionEditorView(foodItem: foodItem, loggedServings: log.servingMultiplier, loggedGrams: log.totalGrams, servingDisplayText: log.servingDisplayText)
            }
        }
    }
    

    private func displayNameForUnit(_ unit: ServingUnit) -> String {
        // For .serving, show the cached parsed unit name
        if unit == .serving {
            return parsedServingUnit
        }
        return unit.rawValue
    }
    
    private func saveChanges() {
        // Fix broken gramsPerServing if needed (from old bug where it was set to 1)
        // If gramsPerServing is suspiciously low and we have a valid log, back-calculate it
        if foodItem.gramsPerServing < 10 && log.servingMultiplier > 0 && log.totalGrams > 10 {
            let correctedGramsPerServing = log.totalGrams / log.servingMultiplier
            foodItem.gramsPerServing = correctedGramsPerServing
        }
        
        // Update the log with new values
        log.servingMultiplier = amountValue
        log.totalGrams = totalGrams
        
        onSave(log)
        dismiss()
    }
}

// MARK: - Nutrition Editor View

// MARK: - Nutrition Editor View

struct NutritionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let foodItem: FoodItem
    
    // Serving size
    @State private var servingDescription: String
    @State private var gramsPerServing: String
    
    // Nutrition per serving
    @State private var calories: String
    @State private var totalFat: String
    @State private var saturatedFat: String
    @State private var transFat: String
    @State private var cholesterol: String
    @State private var sodium: String
    @State private var totalCarbs: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var protein: String
    @State private var vitaminA: String
    @State private var vitaminC: String
    @State private var vitaminD: String
    @State private var calcium: String
    @State private var iron: String
    @State private var potassium: String
    
    init(foodItem: FoodItem, loggedServings: Double? = nil, loggedGrams: Double? = nil, servingDisplayText: String? = nil) {
        self.foodItem = foodItem
        
        // If we have logged amount info, show that instead of the base serving
        let actualServings = loggedServings ?? 1.0
        let actualGrams = loggedGrams ?? foodItem.gramsPerServing
        
        // Use the properly formatted serving display text from the log if available
        let cleanDescription: String
        if let displayText = servingDisplayText {
            // Use the log's formatted serving display (e.g., "4 oz")
            cleanDescription = displayText
        } else if let loggedServings = loggedServings, loggedServings != 1.0 {
            // Fallback: show servings if no display text available
            cleanDescription = String(format: "%.2f servings (%dg)", loggedServings, Int(actualGrams))
                .replacingOccurrences(of: ".00", with: "")
        } else {
            // Just use the base serving description
            cleanDescription = foodItem.servingDescription
        }
        
        _servingDescription = State(initialValue: cleanDescription)
        _gramsPerServing = State(initialValue: String(format: "%.0f", actualGrams))
        
        // Detect if this is old broken data from the bug where manual entries
        // stored per-serving values as per-100g with gramsPerServing hardcoded to 100
        // Heuristic: Manual foods with gramsPerServing=100 but serving description suggesting
        // it's not actually 100g (like "1 serving", "1 container", etc.) are likely broken
        let descLower = foodItem.servingDescription.lowercased()
        let looksLike100g = descLower.contains("100") || descLower.contains("100g")
        let isBrokenData = foodItem.source == "Manual" && 
                          foodItem.gramsPerServing == 100 && 
                          !looksLike100g &&
                          !foodItem.servingSizeIsEstimated // If estimated, it's new and correct
        
        // Calculate multiplier based on actual logged amount
        // If broken, don't convert (values are already per-serving)
        // If correct, convert from per-100g to the actual logged amount
        let servingMultiplier = isBrokenData ? actualServings : (actualGrams / 100.0)
        
        _calories = State(initialValue: String(format: "%.0f", foodItem.caloriesPer100g * servingMultiplier))
        _totalFat = State(initialValue: String(format: "%.1f", foodItem.fatPer100g * servingMultiplier))
        _saturatedFat = State(initialValue: String(format: "%.1f", (foodItem.saturatedFatPer100g ?? 0) * servingMultiplier))
        _transFat = State(initialValue: String(format: "%.1f", (foodItem.transFatPer100g ?? 0) * servingMultiplier))
        _cholesterol = State(initialValue: String(format: "%.0f", (foodItem.cholesterolPer100g ?? 0) * 1000 * servingMultiplier))
        _sodium = State(initialValue: String(format: "%.0f", (foodItem.sodiumPer100g ?? 0) * 1000 * servingMultiplier))
        _totalCarbs = State(initialValue: String(format: "%.1f", foodItem.carbsPer100g * servingMultiplier))
        _fiber = State(initialValue: String(format: "%.1f", (foodItem.fiberPer100g ?? 0) * servingMultiplier))
        _sugar = State(initialValue: String(format: "%.1f", (foodItem.sugarPer100g ?? 0) * servingMultiplier))
        _protein = State(initialValue: String(format: "%.1f", foodItem.proteinPer100g * servingMultiplier))
        _vitaminA = State(initialValue: String(format: "%.0f", (foodItem.vitaminAPer100g ?? 0) * 1_000_000 * servingMultiplier))
        _vitaminC = State(initialValue: String(format: "%.0f", (foodItem.vitaminCPer100g ?? 0) * 1000 * servingMultiplier))
        _vitaminD = State(initialValue: String(format: "%.0f", (foodItem.vitaminDPer100g ?? 0) * 1_000_000 * servingMultiplier))
        _calcium = State(initialValue: String(format: "%.0f", (foodItem.calciumPer100g ?? 0) * 1000 * servingMultiplier))
        _iron = State(initialValue: String(format: "%.1f", (foodItem.ironPer100g ?? 0) * 1000 * servingMultiplier))
        _potassium = State(initialValue: String(format: "%.0f", (foodItem.potassiumPer100g ?? 0) * 1000 * servingMultiplier))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    nutritionCard
                }
                .padding()
            }
            .background(Color("SurfaceBackground"))
            .navigationTitle("Edit Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color("TextSecondary"))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNutrition() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("BrandAccent"))
                }
            }
        }
    }
}

private extension NutritionEditorView {
    
    var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text("Nutrition Facts")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color("TextPrimary"))
            
            Divider().background(Color("TextPrimary"))
            
            servingRow
            Divider()
            
            caloriesRow
            
            thickDivider
            
            fatSection
            Divider()
            
            carbsSection
            Divider()
            
            proteinRow
            
            thickDivider
            
            vitaminSection
        }
        .padding(20)
        .background(Color("SurfacePrimary"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 6)
    }
    
    var thickDivider: some View {
        Rectangle()
            .fill(Color("TextPrimary"))
            .frame(height: 4)
    }
    
    var servingRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Serving Size")
                Spacer()
                TextField("1 cup", text: $servingDescription)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("Grams per Serving")
                Spacer()
                TextField("0", text: $gramsPerServing)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("g")
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .font(.subheadline)
    }
    
    var caloriesRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Calories")
                .font(.system(size: 22, weight: .bold))
            
            Spacer()
            
            TextField("0", text: $calories)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 36, weight: .bold))
                .frame(width: 120)
        }
    }
    
    var fatSection: some View {
        VStack(spacing: 6) {
            labelRow("Total Fat", $totalFat, "g", bold: true)
            labelRow("Saturated Fat", $saturatedFat, "g", indent: true)
            labelRow("Trans Fat", $transFat, "g", indent: true)
            labelRow("Cholesterol", $cholesterol, "mg")
            labelRow("Sodium", $sodium, "mg")
        }
    }
    
    var carbsSection: some View {
        VStack(spacing: 6) {
            labelRow("Total Carbohydrate", $totalCarbs, "g", bold: true)
            labelRow("Dietary Fiber", $fiber, "g", indent: true)
            labelRow("Total Sugars", $sugar, "g", indent: true)
        }
    }
    
    var proteinRow: some View {
        labelRow("Protein", $protein, "g", bold: true)
    }
    
    var vitaminSection: some View {
        VStack(spacing: 6) {
            labelRow("Vitamin A", $vitaminA, "μg")
            labelRow("Vitamin C", $vitaminC, "mg")
            labelRow("Vitamin D", $vitaminD, "μg")
            labelRow("Calcium", $calcium, "mg")
            labelRow("Iron", $iron, "mg")
            labelRow("Potassium", $potassium, "mg")
        }
    }
    
    func labelRow(
        _ title: String,
        _ binding: Binding<String>,
        _ unit: String,
        bold: Bool = false,
        indent: Bool = false
    ) -> some View {
        HStack {
            Text(indent ? "  \(title)" : title)
                .fontWeight(bold ? .semibold : .regular)
            
            Spacer()
            
            TextField("0", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            
            Text(unit)
                .foregroundStyle(Color("TextSecondary"))
        }
        .font(.subheadline)
    }
    
    func saveNutrition() {
        foodItem.servingDescription = servingDescription
        let newGramsPerServing = Double(gramsPerServing) ?? foodItem.gramsPerServing
        foodItem.gramsPerServing = newGramsPerServing
        
        let divisor = newGramsPerServing / 100.0
        
        foodItem.caloriesPer100g = (Double(calories) ?? foodItem.caloriesPer100g) / divisor
        foodItem.proteinPer100g = (Double(protein) ?? foodItem.proteinPer100g) / divisor
        foodItem.carbsPer100g = (Double(totalCarbs) ?? foodItem.carbsPer100g) / divisor
        foodItem.fatPer100g = (Double(totalFat) ?? foodItem.fatPer100g) / divisor
        foodItem.fiberPer100g = (Double(fiber) ?? 0) / divisor
        foodItem.sugarPer100g = (Double(sugar) ?? 0) / divisor
        
        foodItem.saturatedFatPer100g = (Double(saturatedFat) ?? 0) / divisor
        foodItem.transFatPer100g = (Double(transFat) ?? 0) / divisor
        
        foodItem.cholesterolPer100g = ((Double(cholesterol) ?? 0) / 1000) / divisor
        foodItem.sodiumPer100g = ((Double(sodium) ?? 0) / 1000) / divisor
        
        foodItem.vitaminAPer100g = ((Double(vitaminA) ?? 0) / 1_000_000) / divisor
        foodItem.vitaminCPer100g = ((Double(vitaminC) ?? 0) / 1000) / divisor
        foodItem.vitaminDPer100g = ((Double(vitaminD) ?? 0) / 1_000_000) / divisor
        foodItem.calciumPer100g = ((Double(calcium) ?? 0) / 1000) / divisor
        foodItem.ironPer100g = ((Double(iron) ?? 0) / 1000) / divisor
        foodItem.potassiumPer100g = ((Double(potassium) ?? 0) / 1000) / divisor
        
        dismiss()
    }
}
