//
//  TodayView.swift
//  BiteLedger
//

import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var logs: [FoodLog] = []
    @State private var preferences: UserPreferences?

    @State private var selectedMeal: MealType?
    @State private var editingLog: FoodLog?
    @State private var showingDailyNutrition = false
    @State private var showingMealNutrition: MealType?
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var currentStreak = 0

    // MARK: - Computed

    private var todayLogs: [FoodLog] {
        logs
    }

    private var totalCalories: Double {
        todayLogs.reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        todayLogs.reduce(0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Double {
        todayLogs.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalFat: Double {
        todayLogs.reduce(0) { $0 + $1.fat }
    }
    
    private var trackedValue: Double {
        guard let preferences = preferences else { return totalCalories }
        switch preferences.trackingMetric {
        case .calories: return totalCalories
        case .protein: return totalProtein
        case .carbs: return totalCarbs
        case .fat: return totalFat
        }
    }
    
    private var dailyGoal: Double? {
        guard let preferences = preferences, preferences.showDailyGoal else { return nil }
        return preferences.dailyCalorieGoal
    }

    private func caloriesFor(meal: MealType) -> Double {
        todayLogs
            .filter { $0.meal == meal }
            .reduce(0) { $0 + $1.calories }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sticky header with streak
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color("SurfacePrimary"))
                
                ScrollView {
                    VStack(spacing: 16) {
                        compactSummaryBar

                        mealSections

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .background(Color("SurfacePrimary"))
            .navigationBarHidden(true)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width > 0 {
                            // Swipe right - go to previous day
                            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            loadLogsForSelectedDate()
                        } else if value.translation.width < 0 {
                            // Swipe left - go to next day (unless today)
                            if !Calendar.current.isDateInToday(selectedDate) {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                loadLogsForSelectedDate()
                            }
                        }
                    }
            )
            .onAppear {
                loadLogsForSelectedDate()
                loadStreak()
                loadPreferences()
            }
        }
        .sheet(item: $selectedMeal) { meal in
            FoodSearchView(mealType: meal) { addedItem in
                let timestamp: Date

                if Calendar.current.isDateInToday(selectedDate) {
                    timestamp = Date()
                } else {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
                    components.hour = 12
                    timestamp = Calendar.current.date(from: components) ?? selectedDate
                }

                // Only insert FoodItem if it's not already in the context
                // (e.g., when copying from an existing log, the FoodItem already exists)
                if addedItem.foodItem.modelContext == nil {
                    modelContext.insert(addedItem.foodItem)
                    try? modelContext.save()
                }

                let foodLog = FoodLog(
                    foodItem: addedItem.foodItem,
                    timestamp: timestamp,
                    meal: meal,
                    servingMultiplier: addedItem.servings,
                    totalGrams: addedItem.totalGrams,
                    selectedPortionId: addedItem.selectedPortionId
                )

                modelContext.insert(foodLog)
                try? modelContext.save()
                loadLogsForSelectedDate()
            }
        }
        .sheet(item: $editingLog) { log in
            if let foodItem = log.foodItem {
                FoodLogEditView(log: log, foodItem: foodItem) { updatedLog in
                    log.servingMultiplier = updatedLog.servingMultiplier
                    log.totalGrams = updatedLog.totalGrams
                    try? modelContext.save()
                    loadLogsForSelectedDate()
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
                        loadLogsForSelectedDate()
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadLogsForSelectedDate() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.timestamp >= startOfDay && log.timestamp < endOfDay
            },
            sortBy: [SortDescriptor(\FoodLog.timestamp, order: .reverse)]
        )
        
        do {
            logs = try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching logs: \(error)")
            logs = []
        }
    }
    
    private func loadStreak() {
        Task {
            let calendar = Calendar.current
            let allDaysDescriptor = FetchDescriptor<FoodLog>(
                sortBy: [SortDescriptor(\FoodLog.timestamp, order: .reverse)]
            )
            
            do {
                let allLogs = try modelContext.fetch(allDaysDescriptor)
                let uniqueDays = Set(allLogs.map { calendar.startOfDay(for: $0.timestamp) })
                
                var streak = 0
                var checkDate = calendar.startOfDay(for: Date())
                
                while uniqueDays.contains(checkDate) {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                }
                
                currentStreak = streak
            } catch {
                print("Error calculating streak: \(error)")
                currentStreak = 0
            }
        }
    }
    
    private func loadPreferences() {
        let descriptor = FetchDescriptor<UserPreferences>()
        do {
            let results = try modelContext.fetch(descriptor)
            if let existing = results.first {
                preferences = existing
            } else {
                // Create default preferences
                let newPreferences = UserPreferences()
                modelContext.insert(newPreferences)
                try? modelContext.save()
                preferences = newPreferences
            }
        } catch {
            print("Error loading preferences: \(error)")
            let newPreferences = UserPreferences()
            modelContext.insert(newPreferences)
            try? modelContext.save()
            preferences = newPreferences
        }
    }
    
    private func copyMealFromYesterday(meal: MealType) {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday)!
        
        let descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.timestamp >= startOfYesterday && 
                log.timestamp < endOfYesterday &&
                log.meal == meal
            }
        )
        
        do {
            let yesterdayLogs = try modelContext.fetch(descriptor)
            
            for oldLog in yesterdayLogs {
                guard let foodItem = oldLog.foodItem else { continue }
                
                let timestamp: Date
                if Calendar.current.isDateInToday(selectedDate) {
                    timestamp = Date()
                } else {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
                    components.hour = 12
                    timestamp = Calendar.current.date(from: components) ?? selectedDate
                }
                
                let newLog = FoodLog(
                    foodItem: foodItem,
                    timestamp: timestamp,
                    meal: meal,
                    servingMultiplier: oldLog.servingMultiplier,
                    totalGrams: oldLog.totalGrams,
                    selectedPortionId: oldLog.selectedPortionId
                )
                
                modelContext.insert(newLog)
            }
            
            try? modelContext.save()
            loadLogsForSelectedDate()
        } catch {
            print("Error copying meals: \(error)")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                loadLogsForSelectedDate()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(Color("TextSecondary"))
            }

            Spacer()

            Button {
                showingDatePicker = true
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Text(dateDisplayText)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color("TextPrimary"))
                        
                        if currentStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.orange)
                                Text("\(currentStreak)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Text("Daily Ledger")
                        .font(.caption)
                        .foregroundStyle(Color("TextTertiary"))
                }
            }

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                loadLogsForSelectedDate()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(Color("TextSecondary"))
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
            .opacity(Calendar.current.isDateInToday(selectedDate) ? 0.3 : 1)
            

        }
    }
    
    // MARK: - Compact Summary Bar

    private var compactSummaryBar: some View {
        VStack(spacing: 12) {
            // Main tracked metric
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences?.trackingMetric.rawValue ?? "Calories")
                        .font(.caption)
                        .foregroundStyle(Color("TextSecondary"))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(trackedValue))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color("TextPrimary"))
                        
                        if let goal = dailyGoal {
                            Text("/ \(Int(goal))")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(Color("TextSecondary"))
                        }
                        
                        Text(preferences?.trackingMetric.unit ?? "cal")
                            .font(.caption)
                            .foregroundStyle(Color("TextTertiary"))
                    }
                }
                
                Spacer()
                
                // Compact macros
                HStack(spacing: 12) {
                    CompactMacro(label: "P", value: totalProtein, color: Color("MacroProtein"))
                    CompactMacro(label: "C", value: totalCarbs, color: Color("MacroCarbs"))
                    CompactMacro(label: "F", value: totalFat, color: Color("MacroFat"))
                }
            }
            
            // Progress bar (only if goal is set)
            if let goal = dailyGoal {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("DividerSubtle"))
                            .frame(height: 6)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressBarColor)
                            .frame(width: min(geometry.size.width, geometry.size.width * CGFloat(trackedValue / goal)), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("SurfaceCard"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("DividerSubtle"), lineWidth: 1)
        )
        .onTapGesture {
            showingDailyNutrition = true
        }
    }
    
    private var progressBarColor: Color {
        guard let goal = dailyGoal else { return Color("BrandPrimary") }
        let percentage = trackedValue / goal
        if percentage < 0.5 {
            return .green
        } else if percentage < 0.8 {
            return .yellow
        } else if percentage < 1.0 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Meals

    private var mealSections: some View {
        VStack(spacing: 16) {
            ForEach(MealType.allCases, id: \.self) { meal in
                MealDiarySection(
                    meal: meal,
                    logs: todayLogs.filter { $0.meal == meal },
                    calories: caloriesFor(meal: meal),
                    selectedDate: selectedDate,
                    onAddFood: { selectedMeal = meal },
                    onEditLog: { editingLog = $0 },
                    onDeleteLog: { log in
                        modelContext.delete(log)
                        try? modelContext.save()
                        loadLogsForSelectedDate()
                    },
                    onTapMeal: {
                        if !todayLogs.filter({ $0.meal == meal }).isEmpty {
                            showingMealNutrition = meal
                        }
                    },
                    onCopyYesterday: {
                        copyMealFromYesterday(meal: meal)
                    }
                )
            }
        }
    }

    // MARK: - Date Formatting

    private var dateDisplayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        if calendar.isDateInTomorrow(selectedDate) { return "Tomorrow" }

        let formatter = DateFormatter()
        let currentYear = calendar.component(.year, from: Date())
        let selectedYear = calendar.component(.year, from: selectedDate)
        
        // Show year if it's not the current year
        if selectedYear != currentYear {
            formatter.dateFormat = "EEE, MMM d, yyyy"
        } else {
            formatter.dateFormat = "EEE, MMM d"
        }
        
        return formatter.string(from: selectedDate)
    }
}

struct CompactMacro: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color("TextSecondary"))
        }
    }
}



