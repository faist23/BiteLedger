//
//  HistoryView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @State private var allLogs: [FoodLog] = []
    @State private var selectedMealFilter: MealType? = nil // nil = all meals
    @State private var isLoading = true
    @State private var calculatedStreak = 0
    @State private var oldestLogDate: Date?
    @State private var totalUniqueDaysAllTime = 0
    @State private var selectedTimeRange: TimeRange = .thirtyDays
    
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
                            
                            // Goal Charts Section
                            if !activeGoals.isEmpty {
                                goalChartsSection
                            }
                            
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
                loadRecentLogs()
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
    
    // MARK: - Goal Charts Section
    
    private var goalChartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Goal Progress")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("TextPrimary"))
                
                Spacer()
                
                // Time range picker
                Picker("Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal, 4)
            
            ForEach(activeGoals, id: \.rawValue) { nutrient in
                if let goal = userGoals[nutrient.rawValue] {
                    GoalChartCard(
                        nutrient: nutrient,
                        goal: goal,
                        dailyData: dailyTotals(for: nutrient),
                        timeRange: selectedTimeRange
                    )
                }
            }
        }
    }
    
    private var activeGoals: [Nutrient] {
        guard let prefs = preferences.first else { return [] }
        
        // Dashboard order: Calories, Protein, Carbs, Fat, then pinned nutrient
        let pinnedNutrient = prefs.pinnedNutrient.flatMap { Nutrient(rawValue: $0) }
        let dashboardOrder: [Nutrient] = [.calories, .protein, .carbs, .fat, pinnedNutrient].compactMap { $0 }
        
        // Get all nutrients with goals
        let withGoals = prefs.activeGoalNutrients
        
        // Charts appear in dashboard order, then others alphabetically
        let ordered = dashboardOrder.filter { withGoals.contains($0) }
        let remaining = withGoals.filter { !dashboardOrder.contains($0) }.sorted { $0.rawValue < $1.rawValue }
        
        return ordered + remaining
    }
    
    private var userGoals: [String: NutrientGoal] {
        guard let prefs = preferences.first else { return [:] }
        return prefs.goals
    }
    
    private func dailyTotals(for nutrient: Nutrient) -> [(Date, Double)] {
        let calendar = Calendar.current
        let startDate: Date
        
        switch selectedTimeRange {
        case .sevenDays:
            startDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .thirtyDays:
            startDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .ninetyDays:
            startDate = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        }
        
        let recentLogs = allLogs.filter { $0.timestamp >= startDate }
        
        // Group by day
        let grouped = Dictionary(grouping: recentLogs) { log in
            calendar.startOfDay(for: log.timestamp)
        }
        
        return grouped.map { date, logs in
            let total = totalValue(for: nutrient, in: logs)
            return (date, total)
        }
        .sorted { $0.0 < $1.0 }
    }
    
    private func totalValue(for nutrient: Nutrient, in logs: [FoodLog]) -> Double {
        switch nutrient {
        case .calories:
            return logs.reduce(0) { $0 + $1.caloriesAtLogTime }
        case .protein:
            return logs.reduce(0) { $0 + $1.proteinAtLogTime }
        case .carbs:
            return logs.reduce(0) { $0 + $1.carbsAtLogTime }
        case .fat:
            return logs.reduce(0) { $0 + $1.fatAtLogTime }
        case .fiber:
            return logs.reduce(0) { $0 + ($1.fiberAtLogTime ?? 0) }
        case .sugar:
            return logs.reduce(0) { $0 + ($1.sugarAtLogTime ?? 0) }
        case .saturatedFat:
            return logs.reduce(0) { $0 + ($1.saturatedFatAtLogTime ?? 0) }
        case .sodium:
            return logs.reduce(0) { $0 + ($1.sodiumAtLogTime ?? 0) }
        case .potassium:
            return logs.reduce(0) { $0 + ($1.potassiumAtLogTime ?? 0) }
        case .calcium:
            return logs.reduce(0) { $0 + ($1.calciumAtLogTime ?? 0) }
        case .iron:
            return logs.reduce(0) { $0 + ($1.ironAtLogTime ?? 0) }
        case .magnesium:
            return logs.reduce(0) { $0 + ($1.magnesiumAtLogTime ?? 0) }
        case .zinc:
            return logs.reduce(0) { $0 + ($1.zincAtLogTime ?? 0) }
        case .vitaminC:
            return logs.reduce(0) { $0 + ($1.vitaminCAtLogTime ?? 0) }
        case .vitaminD:
            return logs.reduce(0) { $0 + ($1.vitaminDAtLogTime ?? 0) }
        case .vitaminE:
            return logs.reduce(0) { $0 + ($1.vitaminEAtLogTime ?? 0) }
        case .vitaminB6:
            return logs.reduce(0) { $0 + ($1.vitaminB6AtLogTime ?? 0) }
        case .choline:
            return logs.reduce(0) { $0 + ($1.cholineAtLogTime ?? 0) }
        case .caffeine:
            return logs.reduce(0) { $0 + ($1.caffeineAtLogTime ?? 0) }
        case .cholesterol:
            return logs.reduce(0) { $0 + ($1.cholesterolAtLogTime ?? 0) }
        case .vitaminA:
            return logs.reduce(0) { $0 + ($1.vitaminAAtLogTime ?? 0) }
        case .vitaminK:
            return logs.reduce(0) { $0 + ($1.vitaminKAtLogTime ?? 0) }
        case .vitaminB12:
            return logs.reduce(0) { $0 + ($1.vitaminB12AtLogTime ?? 0) }
        case .folate:
            return logs.reduce(0) { $0 + ($1.folateAtLogTime ?? 0) }
        default:
            return 0
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
        
        let totalCalories = recentLogs.reduce(0.0) { $0 + $1.caloriesAtLogTime }
        return Int(totalCalories / Double(daysWithLogs))
    }
    
    private var filteredLogs: [FoodLog] {
        if let mealFilter = selectedMealFilter {
            return allLogs.filter { $0.mealType == mealFilter }
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

// MARK: - Time Range

enum TimeRange: String, CaseIterable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
}

// MARK: - Goal Chart Card

struct GoalChartCard: View {
    let nutrient: Nutrient
    let goal: NutrientGoal
    let dailyData: [(Date, Double)]
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nutrient.rawValue)
                        .font(.headline)
                        .foregroundStyle(Color("TextPrimary"))
                    
                    Text(goalDescription)
                        .font(.caption)
                        .foregroundStyle(Color("TextSecondary"))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(averageValueFormatted)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color("TextPrimary"))
                    
                    Text("avg \(nutrient.unit)/day")
                        .font(.caption2)
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            
            // Rolling average success indicator
            HStack(spacing: 8) {
                Image(systemName: weeklyAverageOnTarget ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(weeklyAverageOnTarget ? .green : .orange)
                    .font(.caption)
                
                Text(weeklyAverageStatusText)
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }
            
            // Chart
            Chart {
                // Daily values as area chart
                ForEach(dailyData, id: \.0) { date, value in
                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Amount", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("BrandPrimary").opacity(0.2), Color("BrandPrimary").opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                // 7-day rolling average line (bold and prominent)
                ForEach(rollingAverageData, id: \.0) { date, avgValue in
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Average", avgValue)
                    )
                    .foregroundStyle(Color("BrandPrimary"))
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)
                }
                
                // Goal threshold line(s)
                switch goal.goalType {
                case .minimum, .maximum:
                    RuleMark(y: .value("Goal", goal.targetValue))
                        .foregroundStyle(.green.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                case .range:
                    let rangeMax = goal.rangeMax ?? (goal.targetValue * 1.1)
                    
                    // Min line
                    RuleMark(y: .value("Min", goal.targetValue))
                        .foregroundStyle(.green.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    
                    // Max line
                    RuleMark(y: .value("Max", rangeMax))
                        .foregroundStyle(.orange.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatValue(amount))
                                .font(.caption2)
                        }
                    }
                }
            }
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color("BrandPrimary").opacity(0.2))
                        .frame(width: 16, height: 12)
                    Text("Daily")
                        .font(.caption2)
                        .foregroundStyle(Color("TextSecondary"))
                }
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color("BrandPrimary"))
                        .frame(width: 16, height: 3)
                    Text("7-Day Avg")
                        .font(.caption2)
                        .foregroundStyle(Color("TextSecondary"))
                }
                
                if goal.goalType == .range {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.green.opacity(0.6))
                            .frame(width: 16, height: 2)
                        Text("Target Range")
                            .font(.caption2)
                            .foregroundStyle(Color("TextSecondary"))
                    }
                } else {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.green.opacity(0.6))
                            .frame(width: 16, height: 2)
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(Color("TextSecondary"))
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color("SurfaceCard"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Computed Properties
    
    private var rollingAverageData: [(Date, Double)] {
        guard dailyData.count >= 2 else { return dailyData }
        
        let sortedData = dailyData.sorted { $0.0 < $1.0 }
        var result: [(Date, Double)] = []
        
        for i in 0..<sortedData.count {
            // Calculate 7-day rolling average (or fewer days if not enough data)
            let startIndex = max(0, i - 6)
            let window = sortedData[startIndex...i]
            let average = window.reduce(0.0) { $0 + $1.1 } / Double(window.count)
            result.append((sortedData[i].0, average))
        }
        
        return result
    }
    
    private var overallAverage: Double {
        guard !dailyData.isEmpty else { return 0 }
        return dailyData.reduce(0.0) { $0 + $1.1 } / Double(dailyData.count)
    }
    
    private var averageValueFormatted: String {
        formatValue(overallAverage)
    }
    
    private var weeklyAverageOnTarget: Bool {
        guard !rollingAverageData.isEmpty else { return false }
        
        // Check the most recent 7-day average
        let recentAverages = rollingAverageData.suffix(7)
        guard let latestAverage = recentAverages.last?.1 else { return false }
        
        switch goal.goalType {
        case .minimum:
            return latestAverage >= goal.targetValue
        case .maximum:
            return latestAverage <= goal.targetValue
        case .range:
            let rangeMax = goal.rangeMax ?? goal.targetValue * 1.1
            return latestAverage >= goal.targetValue && latestAverage <= rangeMax
        }
    }
    
    private var weeklyAverageStatusText: String {
        let recentWindow = min(7, dailyData.count)
        
        if weeklyAverageOnTarget {
            return "7-day rolling average on target"
        } else {
            switch goal.goalType {
            case .minimum:
                return "7-day average below target"
            case .maximum:
                return "7-day average above target"
            case .range:
                if overallAverage < goal.targetValue {
                    return "7-day average below range"
                } else {
                    return "7-day average above range"
                }
            }
        }
    }
    
    private var goalDescription: String {
        switch goal.goalType {
        case .minimum:
            return "At least \(Int(goal.targetValue)) \(nutrient.unit)"
        case .maximum:
            return "Under \(Int(goal.targetValue)) \(nutrient.unit)"
        case .range:
            let max = goal.rangeMax ?? goal.targetValue * 1.1
            return "\(Int(goal.targetValue))-\(Int(max)) \(nutrient.unit)"
        }
    }
    
    
    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .sevenDays:
            return .day
        case .thirtyDays:
            return .weekOfYear
        case .ninetyDays:
            return .weekOfYear
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        // For calories, always show full number (no "k" abbreviation)
        if nutrient == .calories {
            return "\(Int(value))"
        }
        
        // For other nutrients, use compact format
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value >= 100 {
            return "\(Int(value))"
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
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
