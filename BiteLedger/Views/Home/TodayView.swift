//
//  TodayView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//


import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodLog.timestamp, order: .reverse) private var logs: [FoodLog]
    @State private var selectedMeal: MealType?
    @State private var editingLog: FoodLog?
    @State private var showingDailyNutrition = false
    @State private var showingMealNutrition: MealType?
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private var todayLogs: [FoodLog] {
        logs.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDate) }
    }
    
    private var totalCalories: Double {
        todayLogs.reduce(0) { $0 + $1.calories }
    }
    
    private func caloriesFor(meal: MealType) -> Double {
        todayLogs.filter { $0.meal == meal }.reduce(0) { $0 + $1.calories }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date navigation header
                HStack {
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingDatePicker = true
                    } label: {
                        Text(dateDisplayText)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .disabled(Calendar.current.isDateInToday(selectedDate))
                    .opacity(Calendar.current.isDateInToday(selectedDate) ? 0.3 : 1.0)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                ScrollView {
                VStack(spacing: 16) {
                    // Nutrition Summary Card - LoseIt style
                    VStack(spacing: 16) {
                        Text("BUDGET: 2,500 CALS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 40) {
                            // Food consumed
                            VStack(spacing: 4) {
                                Text("Food")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(totalCalories))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            // Circular progress
                            ZStack {
                                Circle()
                                    .stroke(Color.green.opacity(0.3), lineWidth: 12)
                                    .frame(width: 100, height: 100)
                                
                                Circle()
                                    .trim(from: 0, to: min(totalCalories / 2500, 1.0))
                                    .stroke(
                                        totalCalories > 2500 ? Color.red : Color.green,
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                    )
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 2) {
                                    Text("\(Int(2500 - totalCalories))")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundStyle(totalCalories > 2500 ? .red : .primary)
                                    Text(totalCalories > 2500 ? "Over" : "Left")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // Exercise (placeholder)
                            VStack(spacing: 4) {
                                Text("Exercise")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("0")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        // Macro pills
                        HStack(spacing: 12) {
                            MacroPill(
                                label: "Protein",
                                value: todayLogs.reduce(0) { $0 + $1.protein },
                                color: .blue
                            )
                            MacroPill(
                                label: "Carbs",
                                value: todayLogs.reduce(0) { $0 + $1.carbs },
                                color: .orange
                            )
                            MacroPill(
                                label: "Fat",
                                value: todayLogs.reduce(0) { $0 + $1.fat },
                                color: .purple
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingDailyNutrition = true
                    }
                    
                    // Meals - diary style
                    ForEach(MealType.allCases, id: \.self) { meal in
                        MealDiarySection(
                            meal: meal,
                            logs: todayLogs.filter { $0.meal == meal },
                            calories: caloriesFor(meal: meal),
                            onAddFood: {
                                selectedMeal = meal
                            },
                            onEditLog: { log in
                                editingLog = log
                            },
                            onDeleteLog: { log in
                                modelContext.delete(log)
                                try? modelContext.save()
                            },
                            onTapMeal: {
                                showingMealNutrition = meal
                            }
                        )
                    }
                }
                .padding()
            }
        }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedMeal) { meal in
                FoodSearchView(mealType: meal) { addedItem in
                    // Save directly to database
                    // Use selected date, but preserve current time if it's today
                    let timestamp: Date
                    if Calendar.current.isDateInToday(selectedDate) {
                        timestamp = Date() // Use current time for today
                    } else {
                        // For past/future dates, use noon of that day
                        let calendar = Calendar.current
                        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                        components.hour = 12
                        timestamp = calendar.date(from: components) ?? selectedDate
                    }
                    
                    let foodLog = FoodLog(
                        foodItem: addedItem.foodItem,
                        timestamp: timestamp,
                        meal: meal,
                        servingMultiplier: addedItem.servings,
                        totalGrams: addedItem.totalGrams
                    )
                    modelContext.insert(foodLog)
                    try? modelContext.save()
                }
            }
            .sheet(item: $editingLog) { log in
                if let foodItem = log.foodItem {
                    FoodLogEditView(log: log, foodItem: foodItem) { updatedLog in
                        log.servingMultiplier = updatedLog.servingMultiplier
                        log.totalGrams = updatedLog.totalGrams
                        try? modelContext.save()
                    }
                }
            }
            .sheet(isPresented: $showingDailyNutrition) {
                DetailedNutritionView(title: "Daily Nutrition", logs: todayLogs)
            }
            .sheet(item: $showingMealNutrition) { meal in
                DetailedNutritionView(
                    title: "\(meal.rawValue) Nutrition",
                    logs: todayLogs.filter { $0.meal == meal }
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .presentationDetents([.medium])
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingDatePicker = false
                        }
                    }
                }
            }
        }
    }
    
    private var dateDisplayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
}

// MARK: - Meal Diary Section
struct MealDiarySection: View {
    let meal: MealType
    let logs: [FoodLog]
    let calories: Double
    let onAddFood: () -> Void
    let onEditLog: (FoodLog) -> Void
    let onDeleteLog: (FoodLog) -> Void
    let onTapMeal: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(meal.rawValue.uppercased(), systemImage: meal.icon)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if !logs.isEmpty {
                    Text("\(Int(calories)) cal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !logs.isEmpty {
                    onTapMeal()
                }
            }
            
            if logs.isEmpty {
                Button {
                    onAddFood()
                } label: {
                    HStack {
                        Text("Add Food")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    // Use List for swipe actions
                    List {
                        ForEach(logs) { log in
                            if let foodItem = log.foodItem {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(foodItem.name)
                                            .font(.subheadline)
                                        Text(log.servingDisplayText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int(log.calories)) cal")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onEditLog(log)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        onDeleteLog(log)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            }
                        }
                        
                        Button {
                            onAddFood()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Food")
                                Spacer()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(logs.count * 60 + 60))
                }
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Macro Pill
struct MacroPill: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
            Text("\(Int(value))g")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [FoodItem.self, FoodLog.self])
}
