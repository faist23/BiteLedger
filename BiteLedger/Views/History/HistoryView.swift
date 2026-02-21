//
//  HistoryView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var allLogs: [FoodLog] = []
    @State private var selectedMealFilter: MealType? = nil // nil = all meals
    @State private var isLoading = true
    @State private var calculatedStreak = 0
    @State private var oldestLogDate: Date?
    @State private var totalUniqueDaysAllTime = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading your food history...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Stats row
                            statsRow
                            
                            // Meal filter buttons
                            mealFilterButtons
                            
                            // Most logged foods sections
                            mostLoggedFoodsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
            .background(Color("SurfacePrimary"))
            .navigationTitle("History")
            .onAppear {
                if allLogs.isEmpty {
                    loadRecentLogs()
                }
            }
        }
    }
    
    private func loadRecentLogs() {
        Task {
            let calendar = Calendar.current
            
            // Calculate streak efficiently: get all unique days with logs, then count backward from today
            let allDaysDescriptor = FetchDescriptor<FoodLog>(
                sortBy: [SortDescriptor(\FoodLog.timestamp, order: .reverse)]
            )
            
            do {
                // Get all logs to find unique days
                let allHistoricalLogs = try modelContext.fetch(allDaysDescriptor)
                let uniqueDays = Set(allHistoricalLogs.map { calendar.startOfDay(for: $0.timestamp) })
                
                // Calculate streak by checking consecutive days
                var streak = 0
                var checkDate = calendar.startOfDay(for: Date())
                
                while uniqueDays.contains(checkDate) {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                }
                
                // Load 2 years of data for the food frequency display
                let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: Date()) ?? Date()
                let recentLogs = allHistoricalLogs.filter { $0.timestamp >= twoYearsAgo }
                
                // Find the oldest log date from all historical data
                let oldestDate = allHistoricalLogs.last?.timestamp
                
                calculatedStreak = streak
                allLogs = recentLogs
                oldestLogDate = oldestDate
                totalUniqueDaysAllTime = uniqueDays.count
                isLoading = false
            } catch {
                print("Error fetching history logs: \(error)")
                calculatedStreak = 0
                allLogs = []
                oldestLogDate = nil
                totalUniqueDaysAllTime = 0
                isLoading = false
            }
        }
    }
    
    // MARK: - Meal Filter Buttons
    
    private var mealFilterButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MealFilterButton(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedMealFilter == nil
                ) {
                    selectedMealFilter = nil
                }
                
                MealFilterButton(
                    title: "Breakfast",
                    icon: "sunrise.fill",
                    isSelected: selectedMealFilter == .breakfast
                ) {
                    selectedMealFilter = .breakfast
                }
                
                MealFilterButton(
                    title: "Lunch",
                    icon: "sun.max.fill",
                    isSelected: selectedMealFilter == .lunch
                ) {
                    selectedMealFilter = .lunch
                }
                
                MealFilterButton(
                    title: "Dinner",
                    icon: "moon.stars.fill",
                    isSelected: selectedMealFilter == .dinner
                ) {
                    selectedMealFilter = .dinner
                }
                
                MealFilterButton(
                    title: "Snacks",
                    icon: "fork.knife",
                    isSelected: selectedMealFilter == .snack
                ) {
                    selectedMealFilter = .snack
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Streak",
                value: "\(currentStreak)",
                unit: "days",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "Total Days",
                value: "\(totalUniqueDaysAllTime)",
                unit: "\(loggingPercentage)% logged",
                icon: "calendar.badge.checkmark",
                color: .green
            )
            
            StatCard(
                title: "Avg Cal/Day",
                value: "\(averageCaloriesLast30Days)",
                unit: "last 30d",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
        }
    }
    
    // MARK: - Most Logged Foods
    
    private var mostLoggedFoodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Most Logged Foods")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color("TextPrimary"))
                .padding(.horizontal, 4)
            
            // All Time
            FoodFrequencyCard(
                title: "All Time",
                foods: topFoodsAllTime,
                icon: "trophy.fill",
                color: .orange
            )
            
            // This Year
            FoodFrequencyCard(
                title: "This Year",
                foods: topFoodsThisYear,
                icon: "calendar",
                color: .blue
            )
            
            // Last Year
            if !topFoodsLastYear.isEmpty {
                FoodFrequencyCard(
                    title: "Last Year",
                    foods: topFoodsLastYear,
                    icon: "clock.arrow.circlepath",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentStreak: Int {
        // Use pre-calculated streak from full database scan
        return calculatedStreak
    }
    
    private var totalDaysLogged: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(allLogs.map { calendar.startOfDay(for: $0.timestamp) })
        return uniqueDays.count
    }
    
    private var totalDaysSinceStart: Int {
        guard let oldestDate = oldestLogDate else { return 0 }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: oldestDate)
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: startDay, to: today)
        return (components.day ?? 0) + 1
    }
    
    private var loggingPercentage: Int {
        guard totalDaysSinceStart > 0 else { return 0 }
        return Int((Double(totalUniqueDaysAllTime) / Double(totalDaysSinceStart)) * 100)
    }
    
    private var averageCaloriesLast30Days: Int {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let recentLogs = allLogs.filter { $0.timestamp >= thirtyDaysAgo }
        
        // Group by day
        let logsByDay = Dictionary(grouping: recentLogs) { log in
            calendar.startOfDay(for: log.timestamp)
        }
        
        let daysWithLogs = logsByDay.count
        guard daysWithLogs > 0 else { return 0 }
        
        let totalCalories = recentLogs.reduce(0.0) { $0 + $1.calories }
        return Int(totalCalories / Double(daysWithLogs))
    }
    
    private var filteredLogs: [FoodLog] {
        if let mealFilter = selectedMealFilter {
            return allLogs.filter { $0.meal == mealFilter }
        }
        return allLogs
    }
    
    private var topFoodsAllTime: [(name: String, count: Int)] {
        getTopFoods(from: filteredLogs, limit: 10)
    }
    
    private var topFoodsThisYear: [(name: String, count: Int)] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let logsThisYear = filteredLogs.filter { log in
            calendar.component(.year, from: log.timestamp) == currentYear
        }
        return getTopFoods(from: logsThisYear, limit: 5)
    }
    
    private var topFoodsLastYear: [(name: String, count: Int)] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let logsLastYear = filteredLogs.filter { log in
            calendar.component(.year, from: log.timestamp) == currentYear - 1
        }
        return getTopFoods(from: logsLastYear, limit: 5)
    }
    
    private func getTopFoods(from logs: [FoodLog], limit: Int) -> [(name: String, count: Int)] {
        let foodCounts = logs.reduce(into: [String: Int]()) { counts, log in
            guard let foodName = log.foodItem?.name else { return }
            counts[foodName, default: 0] += 1
        }
        
        return foodCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (name: $0.key, count: $0.value) }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color("TextPrimary"))
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("TextSecondary"))
                
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(Color("TextTertiary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color("SurfacePrimary"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Meal Filter Button

struct MealFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.orange : Color("SurfacePrimary"))
            .foregroundStyle(isSelected ? .white : Color("TextPrimary"))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }
}

// MARK: - Food Frequency Card

struct FoodFrequencyCard: View {
    let title: String
    let foods: [(name: String, count: Int)]
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("TextPrimary"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            if foods.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(foods.enumerated()), id: \.offset) { index, food in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(color)
                                .frame(width: 24)
                            
                            Text(food.name)
                                .font(.subheadline)
                                .foregroundStyle(Color("TextPrimary"))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(food.count)×")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("TextSecondary"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        if index < foods.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(Color("SurfacePrimary"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
