//
//  DetailedNutritionView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData

struct DetailedNutritionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let logs: [FoodLog]
    
    // MARK: - Totals
    
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
    
    // MARK: - Macro Calories
    
    private var fatCalories: Double { totalFat * 9 }
    private var carbCalories: Double { totalCarbs * 4 }
    private var proteinCalories: Double { totalProtein * 4 }
    
    private var totalMacroCalories: Double {
        fatCalories + carbCalories + proteinCalories
    }
    
    private var fatPercent: Double {
        totalMacroCalories == 0 ? 0 : fatCalories / totalMacroCalories
    }
    
    private var carbPercent: Double {
        totalMacroCalories == 0 ? 0 : carbCalories / totalMacroCalories
    }
    
    private var proteinPercent: Double {
        totalMacroCalories == 0 ? 0 : proteinCalories / totalMacroCalories
    }
    
    // MARK: - Micronutrient Helper
    
    private func sum(_ keyPath: KeyPath<FoodItem, Double?>) -> Double {
        logs.compactMap { log in
            guard let item = log.foodItem else { return nil }
            let multiplier = log.totalGrams / 100.0
            return (item[keyPath: keyPath] ?? 0) * multiplier
        }
        .reduce(0, +)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Macro Card
                    
                    macroCard
                    
                    // MARK: - Macronutrients
                    
                    nutrientCard(title: "Macronutrients") {
                        nutrientRow("Total Fat", totalFat, "g", bold: true)
                        nutrientRow("Total Carbs", totalCarbs, "g", bold: true)
                        nutrientRow("Protein", totalProtein, "g", bold: true)
                    }
                    
                    // MARK: - Micronutrients
                    
                    nutrientCard(title: "Micronutrients") {
                        micronutrientRows
                    }
                }
                .padding()
            }
            .background(Color("SurfacePrimary"))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("BrandAccent"))
                }
            }
        }
    }
}

private extension DetailedNutritionView {
    
    var macroCard: some View {
        ElevatedCard(padding: 24, cornerRadius: 24) {
            VStack(spacing: 20) {
                
                // Donut
                ZStack {
                    Circle()
                        .stroke(Color("SurfaceTertiary"), lineWidth: 18)
                    
                    Circle()
                        .trim(from: 0, to: fatPercent)
                        .stroke(Color("MacroFat"),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Circle()
                        .trim(from: 0, to: carbPercent)
                        .stroke(Color("MacroCarbs"),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90 + fatPercent * 360))
                    
                    Circle()
                        .trim(from: 0, to: proteinPercent)
                        .stroke(Color("MacroProtein"),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90 + (fatPercent + carbPercent) * 360))
                    
                    VStack(spacing: 4) {
                        Text("\(Int(totalCalories))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        
                        Text("calories")
                            .font(.caption)
                            .foregroundStyle(Color("TextSecondary"))
                    }
                }
                .frame(width: 140, height: 140)
                
                // Legend
                HStack(spacing: 24) {
                    macroLegend("Fat", fatPercent, "MacroFat")
                    macroLegend("Carbs", carbPercent, "MacroCarbs")
                    macroLegend("Protein", proteinPercent, "MacroProtein")
                }
            }
        }
    }
    
    func macroLegend(_ name: String, _ percent: Double, _ color: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color(color))
                .frame(width: 10, height: 10)
            
            Text(name)
                .font(.caption)
                .foregroundStyle(Color("TextSecondary"))
            
            Text("\(Int(percent * 100))%")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

private extension DetailedNutritionView {
    
    func nutrientCard<Content: View>(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {

        ElevatedCard(padding: 20, cornerRadius: 20) {

            VStack(alignment: .leading, spacing: 16) {

                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("TextSecondary"))

                VStack(spacing: 12) {
                    content()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    func nutrientRow(
        _ label: String,
        _ value: Double,
        _ unit: String,
        bold: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .fontWeight(bold ? .semibold : .regular)
            
            Spacer()
            
            Text("\(value, specifier: "%.1f")\(unit)")
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(Color("TextSecondary"))
        }
    }
    
    var micronutrientRows: some View {
        VStack(spacing: 12) {
            nutrientRow("Sodium", sum(\.sodiumPer100g) * 1000, "mg")
            nutrientRow("Fiber", sum(\.fiberPer100g), "g")
            nutrientRow("Sugar", sum(\.sugarPer100g), "g")
            nutrientRow("Calcium", sum(\.calciumPer100g) * 1000, "mg")
            nutrientRow("Iron", sum(\.ironPer100g) * 1000, "mg")
            nutrientRow("Potassium", sum(\.potassiumPer100g) * 1000, "mg")
        }
    }
}

