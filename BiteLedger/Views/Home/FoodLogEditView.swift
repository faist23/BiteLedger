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
    @State private var selectedPortion: ServingSize?
    @State private var showingAmountTextField = false
    @State private var amountTextFieldValue: String = ""
    
    private let foodType: FoodType
    private let parsedServingUnit: String
    private let availableUnits: [ServingUnit]
    private let hasPortions: Bool
    
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
        // Use default serving's label since baseServingDescription no longer exists
        if let defaultServing = foodItem.defaultServing {
            let parsedResult = ServingSizeParser.parse(defaultServing.label)
            if let parsed = parsedResult {
                // Use full display name instead of abbreviation
                self.parsedServingUnit = Self.displayNameForServingUnit(parsed.unit)
            } else {
                self.parsedServingUnit = "Serving"
            }
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

        if let defaultServing = foodItem.defaultServing, let gramWeight = defaultServing.gramWeight, gramWeight > 0 {
            // Only add .serving if the label isn't parseable to a specific unit
            let parsed = ServingSizeParser.parse(defaultServing.label)
            if parsed == nil || parsed?.unit == .serving {
                units.insert(.serving, at: 0)
            }
        }

        // Check if food has serving sizes
        self.hasPortions = !foodItem.servingSizes.isEmpty

        // Initialize selected portion from log's saved serving size
        if let logServingSize = log.servingSize {
            _selectedPortion = State(initialValue: logServingSize)
        } else if foodItem.nutritionMode == .perServing, let firstSize = foodItem.servingSizes.first {
            _selectedPortion = State(initialValue: firstSize)
        }

        // Parse the unit from the LOGGED serving (or default serving as fallback).
        // Using the logged serving ensures the display unit matches what was actually recorded,
        // and that resolvedQuantity will round-trip correctly back to log.quantity.
        let relevantServing = log.servingSize ?? foodItem.defaultServing
        let parsedResult = relevantServing.flatMap { ServingSizeParser.parse($0.label) }

        // If the serving's native unit isn't covered by food-type rules, add it now.
        // E.g. a "2 tbsp" serving on a food not classified as peanutButter/honey/oil.
        if let parsed = parsedResult, parsed.unit != .serving, !units.contains(parsed.unit) {
            units.insert(parsed.unit, at: 0)
        }

        self.availableUnits = units

        // Determine the display unit and initial amount value.
        let displayUnit: ServingUnit
        let parsedAmount: Double?

        if let parsed = parsedResult, parsed.unit != .serving {
            // Serving label parsed to a concrete unit (e.g. "2 tbsp" → .tablespoon, amount 2.0)
            displayUnit = parsed.unit
            parsedAmount = parsed.amount
        } else if relevantServing != nil {
            // Label didn't parse to a specific unit but a serving exists — show as serving count
            displayUnit = .serving
            parsedAmount = nil
        } else {
            // No serving at all — fall back to grams for per100g foods
            let hasServingGrams = foodItem.defaultServing?.gramWeight ?? 0 > 0
            displayUnit = hasServingGrams ? .serving : .gram
            parsedAmount = nil
        }
        _selectedUnit = State(initialValue: displayUnit)

        // Convert log.quantity (always in serving-count units) to the display unit.
        // resolvedQuantity performs the inverse: displayAmount / parsedAmount → serving count.
        // So: displayAmount = log.quantity × parsedAmount  ↔  quantity = displayAmount / parsedAmount
        let currentAmount: Double
        if let parsedAmount, parsedAmount > 0, displayUnit != .serving {
            currentAmount = log.quantity * parsedAmount
        } else {
            currentAmount = log.quantity
        }
        
        let whole = Int(currentAmount)
        let fractionalPart = currentAmount - Double(whole)
        let closestFraction = Fraction.allCases.min(by: { 
            abs($0.rawValue - fractionalPart) < abs($1.rawValue - fractionalPart) 
        }) ?? .zero
        
        _wholeNumber = State(initialValue: whole)
        _fraction = State(initialValue: closestFraction)
    }
    
    private var amountValue: Double {
        Double(wholeNumber) + fraction.rawValue
    }

    // MARK: - Single source of truth for serving and quantity

    /// The serving passed to NutritionCalculator.
    /// Priority: user-picked portion → what was originally logged → food's default serving.
    private var effectiveServing: ServingSize? {
        selectedPortion ?? log.servingSize ?? foodItem.defaultServing
    }

    /// Converts amountValue + selectedUnit into a serving count for NutritionCalculator.
    ///
    /// The init ensures:  amountValue = log.quantity × parsedAmount
    /// So the inverse is: quantity   = amountValue ÷ parsedAmount
    ///
    /// Three cases:
    ///   .serving         → amountValue IS the count directly
    ///   unit == parsed   → divide by parsedAmount to recover the count
    ///   other unit       → gram-based conversion via density / gramWeight
    private var resolvedQuantity: Double {
        if selectedUnit == .serving {
            return amountValue
        }

        if let serving = effectiveServing,
           let parsed = ServingSizeParser.parse(serving.label),
           parsed.unit == selectedUnit,
           parsed.amount > 0 {
            return amountValue / parsed.amount
        }

        // Gram-based fallback (e.g. user switched to Grams or Ounces)
        let density = ServingUnit.densityFor(foodType: foodType)
        let grams = selectedUnit.toGrams(amount: amountValue, density: density)
        if let servingGrams = effectiveServing?.gramWeight, servingGrams > 0 {
            return grams / servingGrams
        }

        return amountValue
    }

    private var totalGrams: Double {
        if let servingGrams = effectiveServing?.gramWeight, servingGrams > 0 {
            return resolvedQuantity * servingGrams
        }
        let density = ServingUnit.densityFor(foodType: foodType)
        return selectedUnit.toGrams(amount: amountValue, density: density)
    }

    private var currentServingDisplayText: String {
        let amountText = formatAmount(amountValue)
        if selectedUnit == .serving {
            let label = effectiveServing?.label ?? "serving"
            return "\(amountText) \(label)"
        }
        return "\(amountText) \(displayNameForUnit(selectedUnit))"
    }

    private var calculatedNutrition: NutritionCalculator.Result {
        // per100g food with no gram weight anywhere — synthesise a temp serving from the
        // total gram amount so NutritionCalculator can scale correctly.
        if foodItem.nutritionMode == .per100g, effectiveServing?.gramWeight == nil {
            let grams = totalGrams
            guard grams > 0 else { return .zero }
            let tempServing = ServingSize(label: "\(Int(grams))g", gramWeight: grams,
                                         isDefault: false, sortOrder: 0)
            return NutritionCalculator.calculate(food: foodItem, serving: tempServing, quantity: 1.0)
        }
        return NutritionCalculator.calculate(
            food: foodItem,
            serving: effectiveServing,
            quantity: resolvedQuantity
        )
    }
    
    private var nutritionLabel: some View {
        ElevatedCard(padding: 0, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 0) {
                // Nutrition Facts Header with Edit button
                HStack {
                    Text("Nutrition Facts")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color("TextPrimary"))
                    
                    Spacer()
                    
                    Button {
                        showingNutritionEditor = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("BrandAccent"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Heavy divider under header
                Rectangle()
                    .fill(Color("TextPrimary"))
                    .frame(height: 8)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                
                VStack(spacing: 0) {
                    nutritionFactsContent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    private var nutritionFactsContent: some View {
        VStack(spacing: 0) {
            // Serving size info - dynamically update based on selections
            Text(currentServingDisplayText)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            
            Text("Amount per serving")
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            
            // Calories
            HStack(alignment: .firstTextBaseline) {
                Text("Calories")
                    .font(.system(size: 32, weight: .black))
                Spacer()
                Text("\(Int(calculatedNutrition.calories))")
                    .font(.system(size: 44, weight: .black))
            }
            .padding(.vertical, 4)
            
            // Heavy divider
            Rectangle()
                .fill(Color("TextPrimary"))
                .frame(height: 6)
                .padding(.vertical, 4)
            
            // % Daily Value header
            HStack {
                Spacer()
                Text("% Daily Value*")
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.bottom, 4)
            
            // Thin divider
            thinDivider()
            
            // Macronutrients
            nutrientRow("Total Fat", calculatedNutrition.fat, "g", bold: true)
            thinDivider()
            
            if let satFat = calculatedNutrition.saturatedFat, satFat > 0 {
                indentedNutrientRow("Saturated Fat", satFat, "g")
                thinDivider()
            }
            
            if let transFat = calculatedNutrition.transFat, transFat > 0 {
                indentedNutrientRow("Trans Fat", transFat, "g")
                thinDivider()
            }
            
            if let monoFat = calculatedNutrition.monounsaturatedFat, monoFat > 0 {
                indentedNutrientRow("Monounsaturated Fat", monoFat, "g")
                thinDivider()
            }
            
            if let polyFat = calculatedNutrition.polyunsaturatedFat, polyFat > 0 {
                indentedNutrientRow("Polyunsaturated Fat", polyFat, "g")
                thinDivider()
            }
            
            if let cholesterol = calculatedNutrition.cholesterol, cholesterol > 0 {
                nutrientRow("Cholesterol", cholesterol, "mg", bold: true)
                thinDivider()
            }
            
            if let sodium = calculatedNutrition.sodium, sodium > 0 {
                nutrientRow("Sodium", sodium, "mg", bold: true)
                thinDivider()
            }
            
            nutrientRow("Total Carbohydrate", calculatedNutrition.carbs, "g", bold: true)
            thinDivider()
            
            if let fiber = calculatedNutrition.fiber, fiber > 0 {
                indentedNutrientRow("Dietary Fiber", fiber, "g")
                thinDivider()
            }
            
            if let sugar = calculatedNutrition.sugar, sugar > 0 {
                indentedNutrientRow("Total Sugars", sugar, "g")
                thinDivider()
            }
            
            nutrientRow("Protein", calculatedNutrition.protein, "g", bold: true)
            
            // Heavy divider before vitamins/minerals
            Rectangle()
                .fill(Color("TextPrimary"))
                .frame(height: 8)
                .padding(.vertical, 4)
            
            // Vitamins and Minerals
            VStack(spacing: 0) {
                if let vitaminD = calculatedNutrition.vitaminD, vitaminD > 0 {
                    nutrientRow("Vitamin D", vitaminD, "mcg")
                    thinDivider()
                }
                
                if let calcium = calculatedNutrition.calcium, calcium > 0 {
                    nutrientRow("Calcium", calcium, "mg")
                    thinDivider()
                }
                
                if let iron = calculatedNutrition.iron, iron > 0 {
                    nutrientRow("Iron", iron, "mg")
                    thinDivider()
                }
                
                if let potassium = calculatedNutrition.potassium, potassium > 0 {
                    nutrientRow("Potassium", potassium, "mg")
                    thinDivider()
                }
                
                if let vitaminA = calculatedNutrition.vitaminA, vitaminA > 0 {
                    nutrientRow("Vitamin A", vitaminA, "mcg")
                    thinDivider()
                }
                
                if let vitaminC = calculatedNutrition.vitaminC, vitaminC > 0 {
                    nutrientRow("Vitamin C", vitaminC, "mg")
                    thinDivider()
                }
                
                if let vitaminE = calculatedNutrition.vitaminE, vitaminE > 0 {
                    nutrientRow("Vitamin E", vitaminE, "mg")
                    thinDivider()
                }
                
                if let vitaminK = calculatedNutrition.vitaminK, vitaminK > 0 {
                    nutrientRow("Vitamin K", vitaminK, "mcg")
                    thinDivider()
                }
                
                if let vitaminB6 = calculatedNutrition.vitaminB6, vitaminB6 > 0 {
                    nutrientRow("Vitamin B6", vitaminB6, "mg")
                    thinDivider()
                }
                
                if let vitaminB12 = calculatedNutrition.vitaminB12, vitaminB12 > 0 {
                    nutrientRow("Vitamin B12", vitaminB12, "mcg")
                    thinDivider()
                }
                
                if let folate = calculatedNutrition.folate, folate > 0 {
                    nutrientRow("Folate", folate, "mcg")
                    thinDivider()
                }
                
                if let choline = calculatedNutrition.choline, choline > 0 {
                    nutrientRow("Choline", choline, "mg")
                    thinDivider()
                }
                
                if let magnesium = calculatedNutrition.magnesium, magnesium > 0 {
                    nutrientRow("Magnesium", magnesium, "mg")
                    thinDivider()
                }
                
                if let zinc = calculatedNutrition.zinc, zinc > 0 {
                    nutrientRow("Zinc", zinc, "mg")
                    thinDivider()
                }
                
                if let caffeine = calculatedNutrition.caffeine, caffeine > 0 {
                    nutrientRow("Caffeine", caffeine, "mg")
                    thinDivider()
                }
            }
            
            // Heavy divider at bottom
            Rectangle()
                .fill(Color("TextPrimary"))
                .frame(height: 4)
                .padding(.top, 4)
            
            // FDA Disclaimer
            Text("* The % Daily Value (DV) tells you how much a nutrient in a serving of food contributes to a daily diet. 2,000 calories a day is used for general nutrition advice.")
                .font(.system(size: 9))
                .foregroundStyle(Color("TextSecondary"))
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // Helper functions
    private func thinDivider() -> some View {
        Rectangle()
            .fill(Color("TextPrimary"))
            .frame(height: 1)
    }
    
    private func nutrientRow(_ label: String, _ value: Double, _ unit: String, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.system(size: 14))
                .fontWeight(bold ? .black : .regular)
            
            Spacer()
            
            Text(formatValue(value) + unit)
                .font(.system(size: 14))
                .fontWeight(bold ? .bold : .regular)
                .frame(minWidth: 60, alignment: .trailing)
            
            if let percent = percentDV(value, for: label) {
                Text("\(percent)%")
                    .font(.system(size: 13))
                    .fontWeight(.light)
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(width: 50, alignment: .trailing)
            } else {
                Text("")
                    .frame(width: 50)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func indentedNutrientRow(_ label: String, _ value: Double, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.system(size: 14))
                .padding(.leading, 20)
            
            Spacer()
            
            Text(formatValue(value) + unit)
                .font(.system(size: 14))
                .frame(minWidth: 60, alignment: .trailing)
            
            if let percent = percentDV(value, for: label) {
                Text("\(percent)%")
                    .font(.system(size: 13))
                    .fontWeight(.light)
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(width: 50, alignment: .trailing)
            } else {
                Text("")
                    .frame(width: 50)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return "\(Int(value))"
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    private func fdaDailyValue(for nutrient: String) -> Double? {
        switch nutrient {
        case "Total Fat": return 78
        case "Saturated Fat": return 20
        case "Cholesterol": return 300
        case "Sodium": return 2300
        case "Total Carbohydrate": return 275
        case "Dietary Fiber": return 28
        case "Total Sugars": return 50
        case "Protein": return 50
        case "Vitamin A": return 900
        case "Vitamin C": return 90
        case "Vitamin D": return 20
        case "Vitamin E": return 15
        case "Vitamin K": return 120
        case "Vitamin B6": return 1.7
        case "Vitamin B12": return 2.4
        case "Folate": return 400
        case "Choline": return 550
        case "Calcium": return 1300
        case "Iron": return 18
        case "Potassium": return 4700
        case "Magnesium": return 420
        case "Zinc": return 11
        default: return nil
        }
    }
    
    private func percentDV(_ value: Double, for label: String) -> Int? {
        guard let dv = fdaDailyValue(for: label), dv > 0 else { return nil }
        return Int((value / dv * 100).rounded())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Product header
                HStack(spacing: 12) {
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
                .background(Color("SurfacePrimary"))
                
                ScrollView {
                    VStack(spacing: 0) {
                        nutritionLabel
                    }
                    .padding()
                }
                
                Spacer(minLength: 16)
                
                // Modern serving controls
                VStack(spacing: 12) {
                    // Portion size selector (only show if there are multiple serving sizes)
                    if foodItem.servingSizes.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Size")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("TextSecondary"))
                            
                            Menu {
                                ForEach(foodItem.servingSizes) { servingSize in
                                    Button {
                                        selectedPortion = servingSize
                                    } label: {
                                        HStack {
                                            Text(servingSize.label.capitalized)
                                            Spacer()
                                            if selectedPortion?.id == servingSize.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedPortion?.label.capitalized ?? "Select size")
                                        .foregroundStyle(Color("TextPrimary"))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(Color("TextSecondary"))
                                        .font(.caption)
                                }
                                .padding(14)
                                .background(Color("SurfaceCard"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("DividerSubtle"), lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // Amount controls
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextSecondary"))
                        
                        HStack(spacing: 12) {
                            // Quantity stepper
                            HStack(spacing: 12) {
                                Button {
                                    decrementAmount()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color("BrandAccent"))
                                }
                                .disabled(amountValue <= 0.25)
                                
                                // Tappable number that switches to text field
                                if showingAmountTextField {
                                    TextField("Amount", text: $amountTextFieldValue)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .frame(minWidth: 80)
                                        .multilineTextAlignment(.center)
                                        .keyboardType(.decimalPad)
                                        .onSubmit {
                                            commitTextFieldAmount()
                                        }
                                        .onAppear {
                                            amountTextFieldValue = String(format: "%.2f", amountValue).replacingOccurrences(of: ".00", with: "")
                                        }
                                } else {
                                    Text(formatAmount(amountValue))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .frame(minWidth: 80)
                                        .multilineTextAlignment(.center)
                                        .onTapGesture {
                                            showingAmountTextField = true
                                            amountTextFieldValue = String(format: "%.2f", amountValue).replacingOccurrences(of: ".00", with: "")
                                        }
                                }
                                
                                Button {
                                    incrementAmount()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color("BrandAccent"))
                                }
                            }
                            
                            Spacer()
                            
                            // Unit selector
                            Menu {
                                ForEach(availableUnits, id: \.id) { unit in
                                    Button {
                                        selectedUnit = unit
                                    } label: {
                                        HStack {
                                            Text(displayNameForUnit(unit))
                                            Spacer()
                                            if selectedUnit == unit {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(displayNameForUnit(selectedUnit))
                                        .foregroundStyle(Color("TextPrimary"))
                                        .fontWeight(.medium)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(Color("TextSecondary"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color("SurfaceCard"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("DividerSubtle"), lineWidth: 1)
                                )
                            }
                        }
                        .padding(16)
                        .background(Color("SurfaceCard"))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color("DividerSubtle"), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                if showingAmountTextField {
                    commitTextFieldAmount()
                }
            }
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
                
                // Keyboard toolbar when text field is active
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        commitTextFieldAmount()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandAccent"))
                }
            }
            .sheet(isPresented: $showingNutritionEditor) {
                NutritionEditorView(foodItem: foodItem, referenceQuantity: resolvedQuantity)
            }
        }
    }
    

    private func displayNameForUnit(_ unit: ServingUnit) -> String {
        // For .serving, show the cached parsed unit name
        if unit == .serving {
            return parsedServingUnit
        }
        // Use proper display names
        switch unit {
        case .gram: return "Grams"
        case .ounce: return "Ounces"
        case .cup: return "Cups"
        case .fluidOunce: return "Fluid Ounces"
        case .tablespoon: return "Tablespoons"
        case .teaspoon: return "Teaspoons"
        case .milliliter: return "Milliliters"
        case .liter: return "Liters"
        case .pound: return "Pounds"
        case .container: return "Containers"
        default: return unit.rawValue
        }
    }
    
    private static func displayNameForServingUnit(_ unit: ServingUnit) -> String {
        switch unit {
        case .gram: return "Grams"
        case .ounce: return "Ounces"
        case .cup: return "Cups"
        case .fluidOunce: return "Fluid Ounces"
        case .tablespoon: return "Tablespoons"
        case .teaspoon: return "Teaspoons"
        case .milliliter: return "Milliliters"
        case .liter: return "Liters"
        case .pound: return "Pounds"
        case .serving: return "Serving"
        case .container: return "Containers"
        }
    }
    
    private func incrementAmount() {
        let currentValue = amountValue
        
        // Smart increment based on current value
        if currentValue < 1 {
            // Below 1: increment by 0.25
            let newFraction = Fraction.allCases.first(where: { $0.rawValue > fraction.rawValue }) ?? .zero
            if newFraction == .zero {
                wholeNumber += 1
                fraction = .zero
            } else {
                fraction = newFraction
            }
        } else if currentValue < 5 {
            // 1-5: increment by 0.5
            if fraction == .zero || fraction == .quarter || fraction == .third {
                fraction = .half
            } else {
                wholeNumber += 1
                fraction = .zero
            }
        } else {
            // Above 5: increment by 1
            wholeNumber += 1
            fraction = .zero
        }
    }
    
    private func decrementAmount() {
        let currentValue = amountValue
        
        guard currentValue > 0.25 else { return }
        
        // Smart decrement based on current value
        if currentValue <= 1 {
            // Below or at 1: decrement by 0.25
            let currentIndex = Fraction.allCases.firstIndex(of: fraction) ?? 0
            if currentIndex > 0 {
                fraction = Fraction.allCases[currentIndex - 1]
            } else if wholeNumber > 0 {
                wholeNumber -= 1
                fraction = .threeQuarters
            }
        } else if currentValue <= 5 {
            // 1-5: decrement by 0.5
            if fraction == .half || fraction == .threeQuarters || fraction == .twoThirds {
                fraction = .zero
            } else if wholeNumber > 0 {
                wholeNumber -= 1
                fraction = .half
            }
        } else {
            // Above 5: decrement by 1
            if fraction == .zero && wholeNumber > 0 {
                wholeNumber -= 1
            } else {
                fraction = .zero
            }
        }
    }
    
    private func formatAmount(_ value: Double) -> String {
        let whole = Int(value)
        let fractionalPart = value - Double(whole)
        
        if fractionalPart < 0.01 {
            return "\(whole)"
        }
        
        // Find closest fraction for display
        let fractionText: String
        if abs(fractionalPart - 0.25) < 0.01 {
            fractionText = "¼"
        } else if abs(fractionalPart - 0.33) < 0.02 {
            fractionText = "⅓"
        } else if abs(fractionalPart - 0.5) < 0.01 {
            fractionText = "½"
        } else if abs(fractionalPart - 0.67) < 0.02 {
            fractionText = "⅔"
        } else if abs(fractionalPart - 0.75) < 0.01 {
            fractionText = "¾"
        } else {
            return String(format: "%.2f", value)
        }
        
        if whole == 0 {
            return fractionText
        } else {
            return "\(whole) \(fractionText)"
        }
    }
    
    private func commitTextFieldAmount() {
        // Parse the text field value
        if let newValue = Double(amountTextFieldValue.replacingOccurrences(of: ",", with: ".")), newValue > 0 {
            // Set the whole number and fraction from the parsed value
            let whole = Int(newValue)
            let fractionalPart = newValue - Double(whole)
            
            wholeNumber = whole
            
            // Find closest fraction
            let closestFraction = Fraction.allCases.min(by: { 
                abs($0.rawValue - fractionalPart) < abs($1.rawValue - fractionalPart) 
            }) ?? .zero
            
            fraction = closestFraction
        }
        
        showingAmountTextField = false
    }
    
    private func saveChanges() {
        // Commit the serving and quantity — use the same effectiveServing / resolvedQuantity
        // the live preview used, so what the user sees is exactly what gets saved.
        let serving = effectiveServing
        log.servingSize = serving
        log.quantity = resolvedQuantity

        let nutrition = NutritionCalculator.calculate(
            food: foodItem,
            serving: serving,
            quantity: resolvedQuantity
        )
        
        // Update all frozen nutrition values
        log.caloriesAtLogTime = nutrition.calories
        log.proteinAtLogTime = nutrition.protein
        log.carbsAtLogTime = nutrition.carbs
        log.fatAtLogTime = nutrition.fat
        log.fiberAtLogTime = nutrition.fiber
        log.sodiumAtLogTime = nutrition.sodium
        log.sugarAtLogTime = nutrition.sugar
        log.saturatedFatAtLogTime = nutrition.saturatedFat
        log.transFatAtLogTime = nutrition.transFat
        log.monounsaturatedFatAtLogTime = nutrition.monounsaturatedFat
        log.polyunsaturatedFatAtLogTime = nutrition.polyunsaturatedFat
        log.cholesterolAtLogTime = nutrition.cholesterol
        log.potassiumAtLogTime = nutrition.potassium
        log.calciumAtLogTime = nutrition.calcium
        log.ironAtLogTime = nutrition.iron
        log.magnesiumAtLogTime = nutrition.magnesium
        log.zincAtLogTime = nutrition.zinc
        log.vitaminAAtLogTime = nutrition.vitaminA
        log.vitaminCAtLogTime = nutrition.vitaminC
        log.vitaminDAtLogTime = nutrition.vitaminD
        log.vitaminEAtLogTime = nutrition.vitaminE
        log.vitaminKAtLogTime = nutrition.vitaminK
        log.vitaminB6AtLogTime = nutrition.vitaminB6
        log.vitaminB12AtLogTime = nutrition.vitaminB12
        log.folateAtLogTime = nutrition.folate
        log.cholineAtLogTime = nutrition.choline
        log.caffeineAtLogTime = nutrition.caffeine
        
        onSave(log)
        dismiss()
    }
}

// MARK: - Nutrition Editor View

struct NutritionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let foodItem: FoodItem

    // Serving size
    @State private var servingDescription: String
    @State private var gramsPerServing: String
    // How many servings the user is entering values for.
    // E.g. 60 for "60 Grams" — all fields are shown at refAmt×base, saved as base.
    @State private var referenceAmount: String

    // Nutrition per serving (base — always 1 serving, never log-quantity scaled)
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
    @State private var vitaminE: String
    @State private var vitaminK: String
    @State private var vitaminB6: String
    @State private var vitaminB12: String
    @State private var folate: String
    @State private var choline: String
    @State private var calcium: String
    @State private var iron: String
    @State private var potassium: String
    @State private var magnesium: String
    @State private var zinc: String
    @State private var caffeine: String

    @State private var dvMode = EditorDVMode()

    /// - referenceQuantity: how many servings the user expects to see.
    ///   Pass `resolvedQuantity` from FoodLogEditView so a food logged as
    ///   "60 Grams" opens the editor showing 225 cal instead of 3.75 cal.
    ///   per100g foods always ignore this and use 1.0.
    init(foodItem: FoodItem, referenceQuantity: Double = 1.0) {
        self.foodItem = foodItem

        // For per100g foods the editor shows the stored per-100g values unchanged.
        // For perServing foods with a bare unit label (e.g. "Grams"), the food
        // stores per-1-unit values; we scale up by the logged quantity so the
        // editor shows recognisable numbers (225 cal, not 3.75 cal).
        let refAmt = foodItem.nutritionMode == .per100g ? 1.0 : max(referenceQuantity, 0.001)

        _servingDescription = State(initialValue: foodItem.defaultServing?.label ?? "1 serving")
        _gramsPerServing = State(initialValue: foodItem.defaultServing?.gramWeight.map { String(format: "%.0f", $0) } ?? "")
        _referenceAmount = State(initialValue: refAmt.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", refAmt) : String(format: "%.4g", refAmt))

        // Scale all fields by refAmt so the editor shows values at the logged quantity.
        _calories    = State(initialValue: String(format: "%.0f", foodItem.calories * refAmt))
        _totalFat    = State(initialValue: String(format: "%.1f", foodItem.fat * refAmt))
        _saturatedFat = State(initialValue: foodItem.saturatedFat.map { String(format: "%.1f", $0 * refAmt) } ?? "")
        _transFat    = State(initialValue: foodItem.transFat.map    { String(format: "%.1f", $0 * refAmt) } ?? "")
        _cholesterol = State(initialValue: foodItem.cholesterol.map { String(format: "%.0f", $0 * refAmt) } ?? "")
        _sodium      = State(initialValue: foodItem.sodium.map      { String(format: "%.0f", $0 * refAmt) } ?? "")
        _totalCarbs  = State(initialValue: String(format: "%.1f", foodItem.carbs * refAmt))
        _fiber       = State(initialValue: foodItem.fiber.map    { String(format: "%.1f", $0 * refAmt) } ?? "")
        _sugar       = State(initialValue: foodItem.sugar.map    { String(format: "%.1f", $0 * refAmt) } ?? "")
        _protein     = State(initialValue: String(format: "%.1f", foodItem.protein * refAmt))
        _vitaminA    = State(initialValue: foodItem.vitaminA.map  { String(format: "%.0f", $0 * refAmt) } ?? "")
        _vitaminC    = State(initialValue: foodItem.vitaminC.map  { String(format: "%.1f", $0 * refAmt) } ?? "")
        _vitaminD    = State(initialValue: foodItem.vitaminD.map  { String(format: "%.0f", $0 * refAmt) } ?? "")
        _vitaminE    = State(initialValue: foodItem.vitaminE.map  { String(format: "%.1f", $0 * refAmt) } ?? "")
        _vitaminK    = State(initialValue: foodItem.vitaminK.map  { String(format: "%.0f", $0 * refAmt) } ?? "")
        _vitaminB6   = State(initialValue: foodItem.vitaminB6.map { String(format: "%.1f", $0 * refAmt) } ?? "")
        _vitaminB12  = State(initialValue: foodItem.vitaminB12.map { String(format: "%.0f", $0 * refAmt) } ?? "")
        _folate      = State(initialValue: foodItem.folate.map   { String(format: "%.0f", $0 * refAmt) } ?? "")
        _choline     = State(initialValue: foodItem.choline.map  { String(format: "%.1f", $0 * refAmt) } ?? "")
        _calcium     = State(initialValue: foodItem.calcium.map  { String(format: "%.1f", $0 * refAmt) } ?? "")
        _iron        = State(initialValue: foodItem.iron.map     { String(format: "%.1f", $0 * refAmt) } ?? "")
        _potassium   = State(initialValue: foodItem.potassium.map { String(format: "%.1f", $0 * refAmt) } ?? "")
        _magnesium   = State(initialValue: foodItem.magnesium.map { String(format: "%.1f", $0 * refAmt) } ?? "")
        _zinc        = State(initialValue: foodItem.zinc.map     { String(format: "%.1f", $0 * refAmt) } ?? "")
        _caffeine    = State(initialValue: foodItem.caffeine.map { String(format: "%.1f", $0 * refAmt) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    nutritionCard
                }
                .padding()
            }
            .background(Color("SurfacePrimary"))
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

// Separate from ManualFoodEntryView's DVMode (which is file-private there)
private struct EditorDVMode {
    var saturatedFat = false; var fiber = false
    var cholesterol = false;  var sodium = false
    var vitaminA = false;  var vitaminC = false;  var vitaminD = false
    var vitaminE = false;  var vitaminK = false;  var vitaminB6 = false
    var vitaminB12 = false; var folate = false;   var choline = false
    var calcium = false;   var iron = false;      var potassium = false
    var magnesium = false; var zinc = false
}

private extension NutritionEditorView {

    func parseDV(_ str: String, dv: Double, usePercent: Bool) -> Double? {
        guard !str.isEmpty, let val = Double(str) else { return nil }
        return usePercent ? val / 100.0 * dv : val
    }

    /// Called when the user commits a new referenceAmount value.
    /// Recomputes all text fields from the FoodItem's base (per-1-serving)
    /// values × the new amount, keeping the math exact.
    func commitReferenceAmount() {
        guard let amt = Double(referenceAmount), amt > 0 else { return }
        recomputeFields(at: amt)
    }

    func recomputeFields(at amt: Double) {
        calories    = String(format: "%.0f", foodItem.calories * amt)
        totalFat    = String(format: "%.1f", foodItem.fat * amt)
        saturatedFat = foodItem.saturatedFat.map { String(format: "%.1f", $0 * amt) } ?? ""
        transFat    = foodItem.transFat.map    { String(format: "%.1f", $0 * amt) } ?? ""
        cholesterol = foodItem.cholesterol.map { String(format: "%.0f", $0 * amt) } ?? ""
        sodium      = foodItem.sodium.map      { String(format: "%.0f", $0 * amt) } ?? ""
        totalCarbs  = String(format: "%.1f", foodItem.carbs * amt)
        fiber       = foodItem.fiber.map    { String(format: "%.1f", $0 * amt) } ?? ""
        sugar       = foodItem.sugar.map    { String(format: "%.1f", $0 * amt) } ?? ""
        protein     = String(format: "%.1f", foodItem.protein * amt)
        vitaminA    = foodItem.vitaminA.map  { String(format: "%.0f", $0 * amt) } ?? ""
        vitaminC    = foodItem.vitaminC.map  { String(format: "%.1f", $0 * amt) } ?? ""
        vitaminD    = foodItem.vitaminD.map  { String(format: "%.0f", $0 * amt) } ?? ""
        vitaminE    = foodItem.vitaminE.map  { String(format: "%.1f", $0 * amt) } ?? ""
        vitaminK    = foodItem.vitaminK.map  { String(format: "%.0f", $0 * amt) } ?? ""
        vitaminB6   = foodItem.vitaminB6.map { String(format: "%.1f", $0 * amt) } ?? ""
        vitaminB12  = foodItem.vitaminB12.map { String(format: "%.0f", $0 * amt) } ?? ""
        folate      = foodItem.folate.map   { String(format: "%.0f", $0 * amt) } ?? ""
        choline     = foodItem.choline.map  { String(format: "%.1f", $0 * amt) } ?? ""
        calcium     = foodItem.calcium.map  { String(format: "%.1f", $0 * amt) } ?? ""
        iron        = foodItem.iron.map     { String(format: "%.1f", $0 * amt) } ?? ""
        potassium   = foodItem.potassium.map { String(format: "%.1f", $0 * amt) } ?? ""
        magnesium   = foodItem.magnesium.map { String(format: "%.1f", $0 * amt) } ?? ""
        zinc        = foodItem.zinc.map     { String(format: "%.1f", $0 * amt) } ?? ""
        caffeine    = foodItem.caffeine.map { String(format: "%.1f", $0 * amt) } ?? ""
        // Reset DV-toggle modes since values are now the recomputed absolutes
        dvMode = EditorDVMode()
    }

    var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            Text("Nutrition Facts")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(Color("TextPrimary"))
                .padding(.bottom, 4)

            Rectangle().fill(Color("TextPrimary")).frame(height: 8)

            // Serving info
            servingRow
                .padding(.vertical, 6)

            thinDivider

            // Calories
            caloriesRow
                .padding(.vertical, 4)

            Rectangle().fill(Color("TextPrimary")).frame(height: 8)

            // % DV header
            Text("% Daily Value*")
                .font(.system(size: 11, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)

            thinDivider

            fatSection

            thinDivider

            carbsSection

            thinDivider

            proteinRow.padding(.vertical, 4)

            Rectangle().fill(Color("TextPrimary")).frame(height: 8)

            Text("Tap a unit (mg, mcg, g) to switch to % Daily Value.")
                .font(.system(size: 10))
                .foregroundStyle(Color("TextSecondary"))
                .padding(.vertical, 4)

            vitaminSection

            thinDivider

            Text("* The % Daily Value tells you how much a nutrient in a serving contributes to a daily diet.")
                .font(.system(size: 9))
                .foregroundStyle(Color("TextSecondary"))
                .padding(.top, 6)
        }
        .padding(20)
        .background(Color("SurfacePrimary"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 6)
    }

    var thinDivider: some View {
        Rectangle().fill(Color("TextPrimary")).frame(height: 1)
    }

    var servingRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Serving Size").fontWeight(.semibold)
                Spacer()
                TextField("1 cup", text: $servingDescription)
                    .multilineTextAlignment(.trailing)
            }
            // "Per X [serving label]" — lets the user work in a recognisable
            // quantity (e.g. 60 Grams = 225 cal) instead of per-1-unit values.
            // Changing the amount and tapping ↵ rescales all fields from the
            // stored base values so the math stays exact.
            HStack(spacing: 4) {
                Text("Per").foregroundStyle(Color("TextSecondary"))
                TextField("1", text: $referenceAmount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 52)
                    .onSubmit { commitReferenceAmount() }
                Text(servingDescription.isEmpty ? "serving" : servingDescription)
                    .foregroundStyle(Color("TextSecondary"))
                    .lineLimit(1)
                Spacer()
            }
            HStack {
                Text("Grams per Serving").foregroundStyle(Color("TextSecondary"))
                Spacer()
                TextField("—", text: $gramsPerServing)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("g").foregroundStyle(Color("TextSecondary"))
            }
        }
        .font(.subheadline)
    }

    var caloriesRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Calories").font(.system(size: 22, weight: .bold))
            Spacer()
            TextField("0", text: $calories)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 36, weight: .bold))
                .frame(width: 120)
        }
    }

    var fatSection: some View {
        VStack(spacing: 0) {
            labelRow("Total Fat", $totalFat, "g", bold: true).padding(.vertical, 3)
            thinDivider
            DVNutrientRow(label: "Saturated Fat", value: $saturatedFat, unit: "g",   dailyValue: 20,   usePercent: $dvMode.saturatedFat, isIndented: true)
                .font(.subheadline).padding(.vertical, 3)
            thinDivider
            labelRow("Trans Fat", $transFat, "g", indent: true).padding(.vertical, 3)
            thinDivider
            DVNutrientRow(label: "Cholesterol",   value: $cholesterol,  unit: "mg",  dailyValue: 300,  usePercent: $dvMode.cholesterol).font(.subheadline).padding(.vertical, 3)
            thinDivider
            DVNutrientRow(label: "Sodium",        value: $sodium,       unit: "mg",  dailyValue: 2300, usePercent: $dvMode.sodium).font(.subheadline).padding(.vertical, 3)
        }
    }

    var carbsSection: some View {
        VStack(spacing: 0) {
            labelRow("Total Carbohydrate", $totalCarbs, "g", bold: true).padding(.vertical, 3)
            thinDivider
            DVNutrientRow(label: "Dietary Fiber", value: $fiber,  unit: "g", dailyValue: 28, usePercent: $dvMode.fiber, isIndented: true)
                .font(.subheadline).padding(.vertical, 3)
            thinDivider
            labelRow("Total Sugars", $sugar, "g", indent: true).padding(.vertical, 3)
        }
    }

    var proteinRow: some View {
        labelRow("Protein", $protein, "g", bold: true)
    }

    var vitaminSection: some View {
        VStack(spacing: 0) {
            dvRow("Vitamin A",   $vitaminA,   "mcg", 900,  $dvMode.vitaminA)
            dvRow("Vitamin C",   $vitaminC,   "mg", 90,   $dvMode.vitaminC)
            dvRow("Vitamin D",   $vitaminD,   "mcg", 20,   $dvMode.vitaminD)
            dvRow("Vitamin E",   $vitaminE,   "mg", 15,   $dvMode.vitaminE)
            dvRow("Vitamin K",   $vitaminK,   "mcg", 120,  $dvMode.vitaminK)
            dvRow("Vitamin B6",  $vitaminB6,  "mg", 1.7,  $dvMode.vitaminB6)
            dvRow("Vitamin B12", $vitaminB12, "mcg", 2.4,  $dvMode.vitaminB12)
            dvRow("Folate",      $folate,     "mcg", 400,  $dvMode.folate)
            dvRow("Choline",     $choline,    "mg", 550,  $dvMode.choline)
            dvRow("Calcium",     $calcium,    "mg", 1300, $dvMode.calcium)
            dvRow("Iron",        $iron,       "mg", 18,   $dvMode.iron)
            dvRow("Potassium",   $potassium,  "mg", 4700, $dvMode.potassium)
            dvRow("Magnesium",   $magnesium,  "mg", 420,  $dvMode.magnesium)
            dvRow("Zinc",        $zinc,       "mg", 11,   $dvMode.zinc)
            labelRow("Caffeine", $caffeine, "mg").padding(.vertical, 3)
        }
    }

    @ViewBuilder
    func dvRow(_ label: String, _ value: Binding<String>, _ unit: String, _ dv: Double, _ usePercent: Binding<Bool>) -> some View {
        DVNutrientRow(label: label, value: value, unit: unit, dailyValue: dv, usePercent: usePercent)
            .font(.subheadline)
            .padding(.vertical, 3)
        thinDivider
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
                .frame(width: 40, alignment: .leading)
        }
        .font(.subheadline)
    }

    func saveNutrition() {
        // All text fields hold values at referenceAmount×base. Divide back to per-1-serving.
        let refAmt = max(Double(referenceAmount) ?? 1.0, 0.001)

        if let defaultServing = foodItem.defaultServing {
            defaultServing.label = servingDescription
            defaultServing.gramWeight = gramsPerServing.isEmpty ? nil : Double(gramsPerServing)
        }

        // Macros (no DV) — divide entered value by refAmt to get per-1-serving
        foodItem.calories = (Double(calories)   ?? foodItem.calories * refAmt) / refAmt
        foodItem.protein  = (Double(protein)    ?? foodItem.protein  * refAmt) / refAmt
        foodItem.carbs    = (Double(totalCarbs) ?? foodItem.carbs    * refAmt) / refAmt
        foodItem.fat      = (Double(totalFat)   ?? foodItem.fat      * refAmt) / refAmt
        foodItem.sugar    = sugar.isEmpty    ? nil : (Double(sugar)    ?? 0) / refAmt
        foodItem.transFat = transFat.isEmpty ? nil : (Double(transFat) ?? 0) / refAmt

        // DV-aware fields — parseDV handles % conversion, then divide by refAmt
        foodItem.saturatedFat = parseDV(saturatedFat, dv: 20,   usePercent: dvMode.saturatedFat).map { $0 / refAmt }
        foodItem.fiber        = parseDV(fiber,        dv: 28,   usePercent: dvMode.fiber).map        { $0 / refAmt }
        foodItem.cholesterol  = parseDV(cholesterol,  dv: 300,  usePercent: dvMode.cholesterol).map  { $0 / refAmt }
        foodItem.sodium       = parseDV(sodium,       dv: 2300, usePercent: dvMode.sodium).map       { $0 / refAmt }
        foodItem.vitaminA     = parseDV(vitaminA,     dv: 900,  usePercent: dvMode.vitaminA).map     { $0 / refAmt }
        foodItem.vitaminC     = parseDV(vitaminC,     dv: 90,   usePercent: dvMode.vitaminC).map     { $0 / refAmt }
        foodItem.vitaminD     = parseDV(vitaminD,     dv: 20,   usePercent: dvMode.vitaminD).map     { $0 / refAmt }
        foodItem.vitaminE     = parseDV(vitaminE,     dv: 15,   usePercent: dvMode.vitaminE).map     { $0 / refAmt }
        foodItem.vitaminK     = parseDV(vitaminK,     dv: 120,  usePercent: dvMode.vitaminK).map     { $0 / refAmt }
        foodItem.vitaminB6    = parseDV(vitaminB6,    dv: 1.7,  usePercent: dvMode.vitaminB6).map    { $0 / refAmt }
        foodItem.vitaminB12   = parseDV(vitaminB12,   dv: 2.4,  usePercent: dvMode.vitaminB12).map   { $0 / refAmt }
        foodItem.folate       = parseDV(folate,       dv: 400,  usePercent: dvMode.folate).map       { $0 / refAmt }
        foodItem.choline      = parseDV(choline,      dv: 550,  usePercent: dvMode.choline).map      { $0 / refAmt }
        foodItem.calcium      = parseDV(calcium,      dv: 1300, usePercent: dvMode.calcium).map      { $0 / refAmt }
        foodItem.iron         = parseDV(iron,         dv: 18,   usePercent: dvMode.iron).map         { $0 / refAmt }
        foodItem.potassium    = parseDV(potassium,    dv: 4700, usePercent: dvMode.potassium).map    { $0 / refAmt }
        foodItem.magnesium    = parseDV(magnesium,    dv: 420,  usePercent: dvMode.magnesium).map    { $0 / refAmt }
        foodItem.zinc         = parseDV(zinc,         dv: 11,   usePercent: dvMode.zinc).map         { $0 / refAmt }
        foodItem.caffeine     = caffeine.isEmpty ? nil : (Double(caffeine) ?? 0) / refAmt

        dismiss()
    }
}
