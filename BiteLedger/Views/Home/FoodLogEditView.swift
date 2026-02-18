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
                .background(Color(.systemGroupedBackground))
                
                Spacer()
                
                // Nutrition header
                HStack {
                    Text("NUTRITION FACTS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showingNutritionEditor = true
                    } label: {
                        Text("EDIT NUTRITION")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                
                // Nutrition display - LoseIt style
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
                .padding(.horizontal, 24)
                .padding(.vertical)
                
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
                .background(Color(.secondarySystemGroupedBackground))
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
                NutritionEditorView(foodItem: foodItem)
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

struct NutritionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let foodItem: FoodItem
    
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var saturatedFat: String
    @State private var transFat: String
    @State private var cholesterol: String
    @State private var sodium: String
    @State private var vitaminA: String
    @State private var vitaminC: String
    @State private var vitaminD: String
    @State private var calcium: String
    @State private var iron: String
    @State private var potassium: String
    
    init(foodItem: FoodItem) {
        self.foodItem = foodItem
        
        _calories = State(initialValue: String(format: "%.1f", foodItem.caloriesPer100g))
        _protein = State(initialValue: String(format: "%.1f", foodItem.proteinPer100g))
        _carbs = State(initialValue: String(format: "%.1f", foodItem.carbsPer100g))
        _fat = State(initialValue: String(format: "%.1f", foodItem.fatPer100g))
        _fiber = State(initialValue: String(format: "%.1f", foodItem.fiberPer100g ?? 0))
        _sugar = State(initialValue: String(format: "%.1f", foodItem.sugarPer100g ?? 0))
        _saturatedFat = State(initialValue: String(format: "%.1f", (foodItem.saturatedFatPer100g ?? 0) * 1000))
        _transFat = State(initialValue: String(format: "%.1f", (foodItem.transFatPer100g ?? 0) * 1000))
        _cholesterol = State(initialValue: String(format: "%.1f", (foodItem.cholesterolPer100g ?? 0) * 1000))
        _sodium = State(initialValue: String(format: "%.1f", (foodItem.sodiumPer100g ?? 0) * 1000))
        _vitaminA = State(initialValue: String(format: "%.1f", (foodItem.vitaminAPer100g ?? 0) * 1000))
        _vitaminC = State(initialValue: String(format: "%.1f", (foodItem.vitaminCPer100g ?? 0) * 1000))
        _vitaminD = State(initialValue: String(format: "%.1f", (foodItem.vitaminDPer100g ?? 0) * 1000))
        _calcium = State(initialValue: String(format: "%.1f", (foodItem.calciumPer100g ?? 0) * 1000))
        _iron = State(initialValue: String(format: "%.1f", (foodItem.ironPer100g ?? 0) * 1000))
        _potassium = State(initialValue: String(format: "%.1f", (foodItem.potassiumPer100g ?? 0) * 1000))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Macronutrients (per 100g)") {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Fiber (g)")
                        Spacer()
                        TextField("0", text: $fiber)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Sugar (g)")
                        Spacer()
                        TextField("0", text: $sugar)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section("Fats (mg per 100g)") {
                    HStack {
                        Text("Saturated Fat")
                        Spacer()
                        TextField("0", text: $saturatedFat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Trans Fat")
                        Spacer()
                        TextField("0", text: $transFat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section("Other Nutrients (mg per 100g)") {
                    HStack {
                        Text("Cholesterol")
                        Spacer()
                        TextField("0", text: $cholesterol)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Sodium")
                        Spacer()
                        TextField("0", text: $sodium)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section("Vitamins & Minerals") {
                    HStack {
                        Text("Vitamin A (μg)")
                        Spacer()
                        TextField("0", text: $vitaminA)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Vitamin C (mg)")
                        Spacer()
                        TextField("0", text: $vitaminC)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Vitamin D (μg)")
                        Spacer()
                        TextField("0", text: $vitaminD)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Calcium (mg)")
                        Spacer()
                        TextField("0", text: $calcium)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Iron (mg)")
                        Spacer()
                        TextField("0", text: $iron)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Potassium (mg)")
                        Spacer()
                        TextField("0", text: $potassium)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }
            .navigationTitle("Edit Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNutrition()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveNutrition() {
        // Update foodItem with new values
        foodItem.caloriesPer100g = Double(calories) ?? foodItem.caloriesPer100g
        foodItem.proteinPer100g = Double(protein) ?? foodItem.proteinPer100g
        foodItem.carbsPer100g = Double(carbs) ?? foodItem.carbsPer100g
        foodItem.fatPer100g = Double(fat) ?? foodItem.fatPer100g
        foodItem.fiberPer100g = Double(fiber) ?? 0
        foodItem.sugarPer100g = Double(sugar) ?? 0
        
        // Convert mg to grams for storage
        foodItem.saturatedFatPer100g = (Double(saturatedFat) ?? 0) / 1000
        foodItem.transFatPer100g = (Double(transFat) ?? 0) / 1000
        foodItem.cholesterolPer100g = (Double(cholesterol) ?? 0) / 1000
        foodItem.sodiumPer100g = (Double(sodium) ?? 0) / 1000
        
        // Convert to grams for storage
        foodItem.vitaminAPer100g = (Double(vitaminA) ?? 0) / 1000
        foodItem.vitaminCPer100g = (Double(vitaminC) ?? 0) / 1000
        foodItem.vitaminDPer100g = (Double(vitaminD) ?? 0) / 1000
        foodItem.calciumPer100g = (Double(calcium) ?? 0) / 1000
        foodItem.ironPer100g = (Double(iron) ?? 0) / 1000
        foodItem.potassiumPer100g = (Double(potassium) ?? 0) / 1000
        
        dismiss()
    }
}
