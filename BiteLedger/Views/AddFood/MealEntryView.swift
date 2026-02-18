import SwiftUI
import SwiftData

/// Meal-focused food entry view - select meal first, then add multiple items
struct MealEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedMeal: MealType = .breakfast
    @State private var showFoodSearch = false
    @State private var addedItems: [AddedFoodItem] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Meal selector at top
                VStack(spacing: 12) {
                    Text("Adding to")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(MealType.allCases, id: \.self) { meal in
                            Label(meal.rawValue, systemImage: meal.icon)
                                .tag(meal)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                
                // Added items list
                if addedItems.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("No items added yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Tap + to add food items to this meal")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(addedItems.indices, id: \.self) { index in
                                AddedItemRow(item: addedItems[index]) {
                                    addedItems.remove(at: index)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Summary at bottom
                    VStack(spacing: 8) {
                        Divider()
                        
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text("\(totalCalories, specifier: "%.0f") cal")
                                .font(.headline)
                        }
                        
                        HStack(spacing: 16) {
                            NutrientPill(label: "P", value: totalProtein, color: .blue)
                            NutrientPill(label: "C", value: totalCarbs, color: .orange)
                            NutrientPill(label: "F", value: totalFat, color: .purple)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFoodSearch = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMeal()
                    }
                    .disabled(addedItems.isEmpty)
                }
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView(mealType: selectedMeal) { foodItem in
                    addedItems.append(foodItem)
                }
            }
        }
    }
    
    private var totalCalories: Double {
        addedItems.reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        addedItems.reduce(0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Double {
        addedItems.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalFat: Double {
        addedItems.reduce(0) { $0 + $1.fat }
    }
    
    private func saveMeal() {
        for item in addedItems {
            let foodLog = FoodLog(
                foodItem: item.foodItem,
                timestamp: Date(),
                meal: selectedMeal,
                servingMultiplier: item.servings,
                totalGrams: item.totalGrams
            )
            modelContext.insert(foodLog)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save meal: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct AddedItemRow: View {
    let item: AddedFoodItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.foodItem.name)
                    .font(.headline)
                
                Text("\(item.servings, specifier: "%.1f") × \(item.foodItem.servingDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.calories, specifier: "%.0f") cal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("P:\(item.protein, specifier: "%.0f") C:\(item.carbs, specifier: "%.0f") F:\(item.fat, specifier: "%.0f")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct NutrientPill: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
            Text("\(value, specifier: "%.0f")g")
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Models

struct AddedFoodItem: Identifiable {
    let id = UUID()
    let foodItem: FoodItem
    let servings: Double
    let totalGrams: Double
    
    var calories: Double {
        foodItem.caloriesPer100g * (totalGrams / 100.0)
    }
    
    var protein: Double {
        foodItem.proteinPer100g * (totalGrams / 100.0)
    }
    
    var carbs: Double {
        foodItem.carbsPer100g * (totalGrams / 100.0)
    }
    
    var fat: Double {
        foodItem.fatPer100g * (totalGrams / 100.0)
    }
}

#Preview {
    MealEntryView()
        .modelContainer(for: FoodLog.self, inMemory: true)
}
