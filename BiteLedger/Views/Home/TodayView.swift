//
//  TodayView.swift
//  BiteLedger
//

import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var logs: [FoodLog] = []

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

    private func caloriesFor(meal: MealType) -> Double {
        todayLogs
            .filter { $0.meal == meal }
            .reduce(0) { $0 + $1.calories }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sticky header
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color("SurfacePrimary"))
                
                // Streak display
                if currentStreak > 0 {
                    streakBanner
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .background(Color("SurfacePrimary"))
                }
                
                ScrollView {
                    VStack(spacing: 28) {
                        calorieSummaryCard

                        macroRow

                        mealSections

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
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

                // Insert and save FoodItem first to ensure portions are persisted
                modelContext.insert(addedItem.foodItem)
                try? modelContext.save()

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
                    Text(dateDisplayText)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("TextPrimary"))

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
    
    // MARK: - Streak Banner
    
    private var streakBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(currentStreak) day streak")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("TextPrimary"))
                
                Text("Keep it going!")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Calorie Card

    private var calorieSummaryCard: some View {
        ElevatedCard(padding: 24, cornerRadius: 24) {
            VStack(spacing: 18) {
                
                VStack(spacing: 4) {
                    Text("\(Int(totalCalories))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("TextPrimary"))
                    
                    Text("calories consumed")
                        .font(.subheadline)
                        .foregroundStyle(Color("TextSecondary"))
                }
                
                ProgressView(value: totalCalories, total: 2500)
                    .tint(Color("BrandPrimary"))
                    .progressViewStyle(.linear)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
        }
        .onTapGesture {
            showingDailyNutrition = true
        }
    }

    // MARK: - Macros

    private var macroRow: some View {
        HStack(spacing: 16) {
            MacroStat(title: "Protein",
                      value: todayLogs.reduce(0) { $0 + $1.protein },
                      color: Color("MacroProtein"))

            MacroStat(title: "Carbs",
                      value: todayLogs.reduce(0) { $0 + $1.carbs },
                      color: Color("MacroCarbs"))

            MacroStat(title: "Fat",
                      value: todayLogs.reduce(0) { $0 + $1.fat },
                      color: Color("MacroFat"))
        }
    }

    // MARK: - Meals

    private var mealSections: some View {
        VStack(spacing: 24) {
            ForEach(MealType.allCases, id: \.self) { meal in
                MealDiarySection(
                    meal: meal,
                    logs: todayLogs.filter { $0.meal == meal },
                    calories: caloriesFor(meal: meal),
                    onAddFood: { selectedMeal = meal },
                    onEditLog: { editingLog = $0 },
                    onDeleteLog: { log in
                        modelContext.delete(log)
                        try? modelContext.save()
                    },
                    onTapMeal: {
                        if !todayLogs.filter({ $0.meal == meal }).isEmpty {
                            showingMealNutrition = meal
                        }
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

struct MacroStat: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        ElevatedCard(padding: 14, cornerRadius: 16) {
            VStack(spacing: 6) {
                Text("\(Int(value))g")
                    .font(.headline)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }
            .frame(maxWidth: .infinity)
        }
    }
}


