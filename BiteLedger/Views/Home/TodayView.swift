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
    @State private var yesterdayLogs: [FoodLog] = []
    @State private var hasLoadedStreak = false

    // MARK: - Computed

    private var todayLogs: [FoodLog] {
        logs
    }

    private func caloriesFor(meal: MealType) -> Double {
        todayLogs
            .filter { $0.mealType == meal }
            .reduce(into: 0) { $0 += $1.caloriesAtLogTime }
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
                        NutritionDashboard(
                            logs: todayLogs,
                            preferences: preferences,
                            onTap: {
                                showingDailyNutrition = true
                            }
                        )
                        .padding(.horizontal, 20)

                        mealSections

                        Spacer(minLength: 60)
                    }
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
                if !hasLoadedStreak {
                    loadStreak()
                    hasLoadedStreak = true
                }
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

                let foodLog = FoodLog.create(
                    mealType: meal,
                    quantity: addedItem.quantity,
                    food: addedItem.foodItem,
                    serving: addedItem.servingSize,
                    timestamp: timestamp
                )

                modelContext.insert(foodLog)
                try? modelContext.save()
                loadLogsForSelectedDate()
            }
        }
        .sheet(item: $editingLog) { log in
            if let foodItem = log.foodItem {
                FoodLogEditView(log: log, foodItem: foodItem) { updatedLog in
                    log.quantity = updatedLog.quantity
                    log.servingSize = updatedLog.servingSize
                    try? modelContext.save()
                    loadLogsForSelectedDate()
                }
            }
        }
        .sheet(isPresented: $showingDailyNutrition) {
            DetailedNutritionView(title: "Daily Nutrition", logs: todayLogs, preferences: preferences)
        }
        .sheet(item: $showingMealNutrition) { meal in
            DetailedNutritionView(
                title: "\(meal.rawValue) Nutrition",
                logs: todayLogs.filter { $0.mealType == meal },
                preferences: preferences
            )
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Today") {
                            selectedDate = Date()
                            showingDatePicker = false
                            loadLogsForSelectedDate()
                        }
                        .disabled(Calendar.current.isDateInToday(selectedDate))
                        .foregroundStyle(Calendar.current.isDateInToday(selectedDate) ? Color.secondary : Color("BrandPrimary"))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingDatePicker = false
                            loadLogsForSelectedDate()
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Data Loading
    
    private func loadLogsForSelectedDate() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay)!

        let todayDescriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.timestamp >= startOfDay && log.timestamp < endOfDay
            },
            sortBy: [SortDescriptor(\FoodLog.timestamp, order: .reverse)]
        )

        let yesterdayDescriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.timestamp >= startOfYesterday && log.timestamp < startOfDay
            }
        )

        do {
            logs = try modelContext.fetch(todayDescriptor)
            yesterdayLogs = try modelContext.fetch(yesterdayDescriptor)
        } catch {
            logs = []
            yesterdayLogs = []
        }
    }

    private func hasYesterdayMeal(_ meal: MealType) -> Bool {
        yesterdayLogs.contains { $0.mealType == meal }
    }

    private func yesterdayCalories(for meal: MealType) -> Double {
        yesterdayLogs.filter { $0.mealType == meal }.reduce(0) { $0 + $1.caloriesAtLogTime }
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
        
        // Fetch all logs from yesterday, then filter by meal in memory
        // (SwiftData predicates can't use captured MealType values)
        let descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.timestamp >= startOfYesterday && 
                log.timestamp < endOfYesterday
            }
        )
        
        do {
            let allYesterdayLogs = try modelContext.fetch(descriptor)
            let yesterdayLogs = allYesterdayLogs.filter { $0.mealType == meal }
            
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
                
                guard let servingSize = oldLog.servingSize else { continue }
                
                // Create new log with same serving size and quantity
                let newLog = FoodLog.create(
                    mealType: meal,
                    quantity: oldLog.quantity,
                    food: foodItem,
                    serving: servingSize,
                    timestamp: timestamp
                )
                
                // Override with cached nutrition from original log to preserve exact values
                newLog.caloriesAtLogTime = oldLog.caloriesAtLogTime
                newLog.proteinAtLogTime = oldLog.proteinAtLogTime
                newLog.carbsAtLogTime = oldLog.carbsAtLogTime
                newLog.fatAtLogTime = oldLog.fatAtLogTime
                newLog.fiberAtLogTime = oldLog.fiberAtLogTime
                newLog.sugarAtLogTime = oldLog.sugarAtLogTime
                newLog.sodiumAtLogTime = oldLog.sodiumAtLogTime
                newLog.saturatedFatAtLogTime = oldLog.saturatedFatAtLogTime
                newLog.transFatAtLogTime = oldLog.transFatAtLogTime
                newLog.monounsaturatedFatAtLogTime = oldLog.monounsaturatedFatAtLogTime
                newLog.polyunsaturatedFatAtLogTime = oldLog.polyunsaturatedFatAtLogTime
                newLog.cholesterolAtLogTime = oldLog.cholesterolAtLogTime
                newLog.magnesiumAtLogTime = oldLog.magnesiumAtLogTime
                newLog.zincAtLogTime = oldLog.zincAtLogTime
                newLog.vitaminAAtLogTime = oldLog.vitaminAAtLogTime
                newLog.vitaminCAtLogTime = oldLog.vitaminCAtLogTime
                newLog.vitaminDAtLogTime = oldLog.vitaminDAtLogTime
                newLog.vitaminEAtLogTime = oldLog.vitaminEAtLogTime
                newLog.vitaminKAtLogTime = oldLog.vitaminKAtLogTime
                newLog.vitaminB6AtLogTime = oldLog.vitaminB6AtLogTime
                newLog.vitaminB12AtLogTime = oldLog.vitaminB12AtLogTime
                newLog.folateAtLogTime = oldLog.folateAtLogTime
                newLog.cholineAtLogTime = oldLog.cholineAtLogTime
                newLog.calciumAtLogTime = oldLog.calciumAtLogTime
                newLog.ironAtLogTime = oldLog.ironAtLogTime
                newLog.potassiumAtLogTime = oldLog.potassiumAtLogTime
                newLog.caffeineAtLogTime = oldLog.caffeineAtLogTime
                
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

    // MARK: - Meals

    private var mealSections: some View {
        VStack(spacing: 16) {
            ForEach(MealType.allCases, id: \.self) { meal in
                MealDiarySection(
                    meal: meal,
                    logs: todayLogs.filter { $0.mealType == meal },
                    calories: caloriesFor(meal: meal),
                    selectedDate: selectedDate,
                    hasYesterdayMeal: hasYesterdayMeal(meal),
                    yesterdayCalories: yesterdayCalories(for: meal),
                    onAddFood: { selectedMeal = meal },
                    onEditLog: { editingLog = $0 },
                    onDeleteLog: { log in
                        modelContext.delete(log)
                        try? modelContext.save()
                        loadLogsForSelectedDate()
                    },
                    onTapMeal: {
                        if !todayLogs.filter({ $0.mealType == meal }).isEmpty {
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

