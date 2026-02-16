//
//  TodayView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//


import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \FoodLog.timestamp, order: .reverse) private var logs: [FoodLog]
    @State private var showingAddFood = false
    
    private var todayLogs: [FoodLog] {
        logs.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    private var totalCalories: Double {
        todayLogs.reduce(0) { $0 + $1.calories }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Nutrition Summary Card
                    NutritionSummaryCard(
                        calories: totalCalories,
                        protein: todayLogs.reduce(0) { $0 + $1.protein },
                        carbs: todayLogs.reduce(0) { $0 + $1.carbs },
                        fat: todayLogs.reduce(0) { $0 + $1.fat }
                    )
                    
                    // Meals
                    ForEach(MealType.allCases, id: \.self) { meal in
                        MealSection(
                            meal: meal,
                            logs: todayLogs.filter { $0.meal == meal }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddFood = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [FoodItem.self, FoodLog.self])
}