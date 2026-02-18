//
//  DetailedNutritionView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData

/// Detailed nutrition breakdown for a meal or daily total
struct DetailedNutritionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let logs: [FoodLog]
    
    private var totalCalories: Double {
        logs.reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        logs.reduce(0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Double {
        logs.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalFat: Double {
        logs.reduce(0) { $0 + $1.fat }
    }
    
    private func sumMicronutrient(_ keyPath: KeyPath<FoodItem, Double?>) -> Double {
        logs.compactMap { log in
            guard let foodItem = log.foodItem else { return nil }
            let multiplier = log.totalGrams / 100.0
            return (foodItem[keyPath: keyPath] ?? 0) * multiplier
        }.reduce(0, +)
    }
    
    // Calculate macro percentages (normalized to sum to 100%)
    private var fatCalories: Double {
        totalFat * 9
    }
    
    private var carbCalories: Double {
        totalCarbs * 4
    }
    
    private var proteinCalories: Double {
        totalProtein * 4
    }
    
    private var totalMacroCalories: Double {
        fatCalories + carbCalories + proteinCalories
    }
    
    private var fatPercentage: Double {
        guard totalMacroCalories > 0 else { return 0 }
        return fatCalories / totalMacroCalories
    }
    
    private var carbPercentage: Double {
        guard totalMacroCalories > 0 else { return 0 }
        return carbCalories / totalMacroCalories
    }
    
    private var proteinPercentage: Double {
        guard totalMacroCalories > 0 else { return 0 }
        return proteinCalories / totalMacroCalories
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Macro Donut Chart
                    HStack(spacing: 32) {
                        // Donut Chart
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                                .frame(width: 120, height: 120)
                            
                            // Fat segment
                            Circle()
                                .trim(from: 0, to: fatPercentage)
                                .stroke(Color.purple, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))
                            
                            // Carbs segment
                            Circle()
                                .trim(from: 0, to: carbPercentage)
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90 + fatPercentage * 360))
                            
                            // Protein segment
                            Circle()
                                .trim(from: 0, to: proteinPercentage)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90 + (fatPercentage + carbPercentage) * 360))
                            
                            VStack(spacing: 2) {
                                Text("\(Int(totalCalories))")
                                    .font(.system(size: 24, weight: .bold))
                                Text("cal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Macro Legend
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 12, height: 12)
                                Text("Fat")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(fatPercentage * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 12, height: 12)
                                Text("Carbs")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(carbPercentage * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 12, height: 12)
                                Text("Protein")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(proteinPercentage * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(width: 120)
                    }
                    .padding(.top)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Nutrition Label Style List
                    VStack(alignment: .leading, spacing: 0) {
                        // Calculate all nutrients once
                        let saturatedFat = sumMicronutrient(\.saturatedFatPer100g)
                        let transFat = sumMicronutrient(\.transFatPer100g)
                        let cholesterol = sumMicronutrient(\.cholesterolPer100g)
                        let sodium = sumMicronutrient(\.sodiumPer100g)
                        let fiber = sumMicronutrient(\.fiberPer100g)
                        let sugar = sumMicronutrient(\.sugarPer100g)
                        let vitaminA = sumMicronutrient(\.vitaminAPer100g)
                        let vitaminC = sumMicronutrient(\.vitaminCPer100g)
                        let vitaminD = sumMicronutrient(\.vitaminDPer100g)
                        let calcium = sumMicronutrient(\.calciumPer100g)
                        let iron = sumMicronutrient(\.ironPer100g)
                        let potassium = sumMicronutrient(\.potassiumPer100g)
                        
                        // Total Fat with sub-items
                        NutritionLabelRow(label: "Total Fat", value: totalFat, unit: "g", isBold: true)
                        Divider().padding(.leading, 16)
                        
                        if saturatedFat > 0 {
                            NutritionLabelRow(label: "Saturated Fat", value: saturatedFat, unit: "g", isIndented: true)
                            Divider().padding(.leading, 16)
                        }
                        
                        if transFat > 0 {
                            NutritionLabelRow(label: "Trans Fat", value: transFat, unit: "g", isIndented: true)
                            Divider().padding(.leading, 16)
                        }
                        
                        if cholesterol > 0 {
                            NutritionLabelRow(label: "Cholesterol", value: cholesterol * 1000, unit: "mg", isIndented: true)
                            Divider().padding(.leading, 16)
                        }
                        
                        if sodium > 0 {
                            NutritionLabelRow(label: "Sodium", value: sodium * 1000, unit: "mg", isIndented: true)
                            Divider().padding(.leading, 16)
                        }
                        
                        // Total Carbohydrates with sub-items
                        NutritionLabelRow(label: "Total Carbohydrates", value: totalCarbs, unit: "g", isBold: true)
                        Divider().padding(.leading, 16)
                        
                        if fiber > 0 {
                            NutritionLabelRow(label: "Dietary Fiber", value: fiber, unit: "g", isIndented: true)
                            Divider().padding(.leading, 16)
                        }
                        
                        if sugar > 0 {
                            NutritionLabelRow(label: "Sugars", value: sugar, unit: "g", isIndented: true)
                            Divider().padding(.leading, 16)
                        }
                        
                        // Protein
                        NutritionLabelRow(label: "Protein", value: totalProtein, unit: "g", isBold: true)
                        
                        // Vitamins & Minerals
                        if vitaminA > 0 || vitaminC > 0 || vitaminD > 0 || calcium > 0 || iron > 0 || potassium > 0 {
                            Divider().padding(.leading, 16)
                            
                            if vitaminA > 0 {
                                NutritionLabelRow(label: "Vitamin A", value: vitaminA * 1000, unit: "μg")
                                Divider().padding(.leading, 16)
                            }
                            
                            if vitaminC > 0 {
                                NutritionLabelRow(label: "Vitamin C", value: vitaminC * 1000, unit: "mg")
                                Divider().padding(.leading, 16)
                            }
                            
                            if vitaminD > 0 {
                                NutritionLabelRow(label: "Vitamin D", value: vitaminD * 1000, unit: "μg")
                                Divider().padding(.leading, 16)
                            }
                            
                            if calcium > 0 {
                                NutritionLabelRow(label: "Calcium", value: calcium * 1000, unit: "mg")
                                Divider().padding(.leading, 16)
                            }
                            
                            if iron > 0 {
                                NutritionLabelRow(label: "Iron", value: iron * 1000, unit: "mg")
                                Divider().padding(.leading, 16)
                            }
                            
                            if potassium > 0 {
                                NutritionLabelRow(label: "Potassium", value: potassium * 1000, unit: "mg")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle(title)
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
}

// MARK: - Nutrition Label Row

struct NutritionLabelRow: View {
    let label: String
    let value: Double
    let unit: String
    var isBold: Bool = false
    var isIndented: Bool = false
    
    var body: some View {
        HStack {
            if isIndented {
                Text("  \(label)")
                    .font(.subheadline)
            } else {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isBold ? .semibold : .regular)
            }
            
            Spacer()
            
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.subheadline)
                .fontWeight(isBold ? .semibold : .regular)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
