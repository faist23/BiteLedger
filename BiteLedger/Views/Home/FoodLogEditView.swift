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
    @State private var selectedPortion: StoredPortion?
    
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
        
        // Check if food has portions
        self.hasPortions = (foodItem.portions?.isEmpty == false)
        
        // Initialize selected portion from log's saved portion ID
        if let portionId = log.selectedPortionId,
           let portions = foodItem.portions,
           let savedPortion = portions.first(where: { $0.id == portionId }) {
            _selectedPortion = State(initialValue: savedPortion)
        } else if let portions = foodItem.portions, let firstPortion = portions.first {
            // Fallback to first portion if no saved selection
            _selectedPortion = State(initialValue: firstPortion)
        }
        
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
        // If a portion is selected, use its gram weight
        if let portion = selectedPortion {
            return amountValue * portion.gramWeight
        }
        
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
    
    private var currentServingDisplayText: String {
        // If a portion is selected, show it with amount
        if let portion = selectedPortion {
            return formatAmount(amountValue) + " " + portion.modifier
        }
        
        // Otherwise format based on selected unit
        let amountText = formatAmount(amountValue)
        let unitText = displayNameForUnit(selectedUnit)
        
        return "\(amountText) \(unitText)"
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
                Text("\(Int(calculatedNutrition.caloriesPer100g))")
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
            nutrientRow("Total Fat", calculatedNutrition.fatPer100g, "g", bold: true)
            thinDivider()
            
            if let satFat = foodItem.saturatedFatPer100g, satFat > 0 {
                indentedNutrientRow("Saturated Fat", satFat * nutritionMultiplier, "g")
                thinDivider()
            }
            
            if let transFat = foodItem.transFatPer100g, transFat > 0 {
                indentedNutrientRow("Trans Fat", transFat * nutritionMultiplier, "g")
                thinDivider()
            }
            
            if let monoFat = foodItem.monounsaturatedFatPer100g, monoFat > 0 {
                indentedNutrientRow("Monounsaturated Fat", monoFat * nutritionMultiplier, "g")
                thinDivider()
            }
            
            if let polyFat = foodItem.polyunsaturatedFatPer100g, polyFat > 0 {
                indentedNutrientRow("Polyunsaturated Fat", polyFat * nutritionMultiplier, "g")
                thinDivider()
            }
            
            if let cholesterol = foodItem.cholesterolPer100g, cholesterol > 0 {
                nutrientRow("Cholesterol", cholesterol * nutritionMultiplier * 1000, "mg", bold: true)
                thinDivider()
            }
            
            if let sodium = foodItem.sodiumPer100g, sodium > 0 {
                nutrientRow("Sodium", sodium * nutritionMultiplier * 1000, "mg", bold: true)
                thinDivider()
            }
            
            nutrientRow("Total Carbohydrate", calculatedNutrition.carbsPer100g, "g", bold: true)
            thinDivider()
            
            if let fiber = foodItem.fiberPer100g, fiber > 0 {
                indentedNutrientRow("Dietary Fiber", fiber * nutritionMultiplier, "g")
                thinDivider()
            }
            
            if let sugar = foodItem.sugarPer100g, sugar > 0 {
                indentedNutrientRow("Total Sugars", sugar * nutritionMultiplier, "g")
                thinDivider()
            }
            
            nutrientRow("Protein", calculatedNutrition.proteinPer100g, "g", bold: true)
            
            // Heavy divider before vitamins/minerals
            Rectangle()
                .fill(Color("TextPrimary"))
                .frame(height: 8)
                .padding(.vertical, 4)
            
            // Vitamins and Minerals
            VStack(spacing: 0) {
                if let vitaminD = foodItem.vitaminDPer100g, vitaminD > 0 {
                    nutrientRow("Vitamin D", vitaminD * nutritionMultiplier * 1_000_000, "mcg")
                    thinDivider()
                }
                
                if let calcium = foodItem.calciumPer100g, calcium > 0 {
                    nutrientRow("Calcium", calcium * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let iron = foodItem.ironPer100g, iron > 0 {
                    nutrientRow("Iron", iron * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let potassium = foodItem.potassiumPer100g, potassium > 0 {
                    nutrientRow("Potassium", potassium * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let vitaminA = foodItem.vitaminAPer100g, vitaminA > 0 {
                    nutrientRow("Vitamin A", vitaminA * nutritionMultiplier * 1_000_000, "mcg")
                    thinDivider()
                }
                
                if let vitaminC = foodItem.vitaminCPer100g, vitaminC > 0 {
                    nutrientRow("Vitamin C", vitaminC * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let vitaminE = foodItem.vitaminEPer100g, vitaminE > 0 {
                    nutrientRow("Vitamin E", vitaminE * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let vitaminK = foodItem.vitaminKPer100g, vitaminK > 0 {
                    nutrientRow("Vitamin K", vitaminK * nutritionMultiplier * 1_000_000, "mcg")
                    thinDivider()
                }
                
                if let vitaminB6 = foodItem.vitaminB6Per100g, vitaminB6 > 0 {
                    nutrientRow("Vitamin B6", vitaminB6 * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let vitaminB12 = foodItem.vitaminB12Per100g, vitaminB12 > 0 {
                    nutrientRow("Vitamin B12", vitaminB12 * nutritionMultiplier * 1_000_000, "mcg")
                    thinDivider()
                }
                
                if let folate = foodItem.folatePer100g, folate > 0 {
                    nutrientRow("Folate", folate * nutritionMultiplier * 1_000_000, "mcg")
                    thinDivider()
                }
                
                if let choline = foodItem.cholinePer100g, choline > 0 {
                    nutrientRow("Choline", choline * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let magnesium = foodItem.magnesiumPer100g, magnesium > 0 {
                    nutrientRow("Magnesium", magnesium * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let zinc = foodItem.zincPer100g, zinc > 0 {
                    nutrientRow("Zinc", zinc * nutritionMultiplier * 1000, "mg")
                    thinDivider()
                }
                
                if let caffeine = foodItem.caffeinePer100g, caffeine > 0 {
                    nutrientRow("Caffeine", caffeine * nutritionMultiplier * 1000, "mg")
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
                    // Portion size selector (if portions are available)
                    if hasPortions, let portions = foodItem.portions {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Size")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("TextSecondary"))
                            
                            Menu {
                                ForEach(portions) { portion in
                                    Button {
                                        selectedPortion = portion
                                    } label: {
                                        HStack {
                                            Text(portion.modifier.capitalized)
                                            Spacer()
                                            if selectedPortion?.id == portion.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedPortion?.modifier.capitalized ?? "Select size")
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
                                
                                Text(formatAmount(amountValue))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .frame(minWidth: 80)
                                    .multilineTextAlignment(.center)
                                
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
        log.selectedPortionId = selectedPortion?.id
        
        // Set displayUnit based on what unit was selected
        // This ensures the log shows the correct unit (e.g., "60g" not "60 cups")
        if selectedUnit == .gram {
            log.displayUnit = "g"
        } else if selectedUnit == .ounce {
            log.displayUnit = "oz"
        } else {
            // For other units (serving, cup, tbsp, etc.), clear displayUnit
            // so it uses the default logic based on servingDescription
            log.displayUnit = nil
        }
        
        // Recalculate cached nutrition based on new portion/amount
        let multiplier = totalGrams / 100.0
        log.calories = foodItem.caloriesPer100g * multiplier
        log.protein = foodItem.proteinPer100g * multiplier
        log.carbs = foodItem.carbsPer100g * multiplier
        log.fat = foodItem.fatPer100g * multiplier
        
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
        _vitaminE = State(initialValue: String(format: "%.1f", (foodItem.vitaminEPer100g ?? 0) * 1000 * servingMultiplier))
        _vitaminK = State(initialValue: String(format: "%.0f", (foodItem.vitaminKPer100g ?? 0) * 1_000_000 * servingMultiplier))
        _vitaminB6 = State(initialValue: String(format: "%.1f", (foodItem.vitaminB6Per100g ?? 0) * 1000 * servingMultiplier))
        _vitaminB12 = State(initialValue: String(format: "%.1f", (foodItem.vitaminB12Per100g ?? 0) * 1_000_000 * servingMultiplier))
        _folate = State(initialValue: String(format: "%.0f", (foodItem.folatePer100g ?? 0) * 1_000_000 * servingMultiplier))
        _choline = State(initialValue: String(format: "%.1f", (foodItem.cholinePer100g ?? 0) * 1000 * servingMultiplier))
        _calcium = State(initialValue: String(format: "%.0f", (foodItem.calciumPer100g ?? 0) * 1000 * servingMultiplier))
        _iron = State(initialValue: String(format: "%.1f", (foodItem.ironPer100g ?? 0) * 1000 * servingMultiplier))
        _potassium = State(initialValue: String(format: "%.0f", (foodItem.potassiumPer100g ?? 0) * 1000 * servingMultiplier))
        _magnesium = State(initialValue: String(format: "%.0f", (foodItem.magnesiumPer100g ?? 0) * 1000 * servingMultiplier))
        _zinc = State(initialValue: String(format: "%.1f", (foodItem.zincPer100g ?? 0) * 1000 * servingMultiplier))
        _caffeine = State(initialValue: String(format: "%.0f", (foodItem.caffeinePer100g ?? 0) * 1000 * servingMultiplier))
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
            labelRow("Vitamin E", $vitaminE, "mg")
            labelRow("Vitamin K", $vitaminK, "μg")
            labelRow("Vitamin B6", $vitaminB6, "mg")
            labelRow("Vitamin B12", $vitaminB12, "μg")
            labelRow("Folate", $folate, "μg")
            labelRow("Choline", $choline, "mg")
            labelRow("Calcium", $calcium, "mg")
            labelRow("Iron", $iron, "mg")
            labelRow("Potassium", $potassium, "mg")
            labelRow("Magnesium", $magnesium, "mg")
            labelRow("Zinc", $zinc, "mg")
            labelRow("Caffeine", $caffeine, "mg")
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
        foodItem.vitaminEPer100g = ((Double(vitaminE) ?? 0) / 1000) / divisor
        foodItem.vitaminKPer100g = ((Double(vitaminK) ?? 0) / 1_000_000) / divisor
        foodItem.vitaminB6Per100g = ((Double(vitaminB6) ?? 0) / 1000) / divisor
        foodItem.vitaminB12Per100g = ((Double(vitaminB12) ?? 0) / 1_000_000) / divisor
        foodItem.folatePer100g = ((Double(folate) ?? 0) / 1_000_000) / divisor
        foodItem.cholinePer100g = ((Double(choline) ?? 0) / 1000) / divisor
        foodItem.calciumPer100g = ((Double(calcium) ?? 0) / 1000) / divisor
        foodItem.ironPer100g = ((Double(iron) ?? 0) / 1000) / divisor
        foodItem.potassiumPer100g = ((Double(potassium) ?? 0) / 1000) / divisor
        foodItem.magnesiumPer100g = ((Double(magnesium) ?? 0) / 1000) / divisor
        foodItem.zincPer100g = ((Double(zinc) ?? 0) / 1000) / divisor
        foodItem.caffeinePer100g = ((Double(caffeine) ?? 0) / 1000) / divisor
        
        dismiss()
    }
}
