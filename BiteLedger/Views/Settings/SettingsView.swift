//
//  SettingsView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//


import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allLogs: [FoodLog]
    @Query private var preferences: [UserPreferences]
    
    private var foodItemsCount: Int {
        let descriptor = FetchDescriptor<FoodItem>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    @State private var showingImport = false
    @State private var showingExport = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCleanupConfirmation = false
    @State private var cleanupResultMessage = ""
    @State private var showingCleanupResult = false
    @State private var isDeleting = false
    @State private var deleteProgress = ""
    @State private var pinnedNutrient: Nutrient?
    @State private var showMacroBalance: Bool = true
    @State private var goals: [String: NutrientGoal] = [:]
    @State private var editingNutrient: Nutrient?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Show Macro Balance Tile", isOn: $showMacroBalance)
                        .onChange(of: showMacroBalance) { _, _ in
                            updatePreferences()
                        }
                    
                    Picker("Pin Nutrient to Dashboard", selection: $pinnedNutrient) {
                        Text("None").tag(nil as Nutrient?)
                        ForEach(Nutrient.pinnableNutrients) { nutrient in
                            Text(nutrient.rawValue).tag(nutrient as Nutrient?)
                        }
                    }
                    .onChange(of: pinnedNutrient) { _, _ in
                        updatePreferences()
                    }
                } header: {
                    Text("Dashboard")
                } footer: {
                    Text("The macro balance tile shows your protein/carbs/fat breakdown. Choose an additional nutrient for the 5th tile.")
                }
                
                Section {
                    // Always show Big 4
                    GoalRow(nutrient: .calories, goals: $goals, onUpdate: updatePreferences)
                    GoalRow(nutrient: .protein, goals: $goals, onUpdate: updatePreferences)
                    GoalRow(nutrient: .carbs, goals: $goals, onUpdate: updatePreferences)
                    GoalRow(nutrient: .fat, goals: $goals, onUpdate: updatePreferences)
                    
                    // Show 5th slot if nutrient is pinned
                    if let pinned = pinnedNutrient {
                        GoalRow(nutrient: pinned, goals: $goals, onUpdate: updatePreferences)
                    }
                } header: {
                    Text("Goals")
                } footer: {
                    Text("Set goals for any nutrients on your dashboard. Progress bars will appear automatically.")
                }
                
                Section {
                    NavigationLink {
                        MyFoodsManagementView()
                    } label: {
                        HStack {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(.blue)
                            Text("My Foods")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        showingExport = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.green)
                            Text("Export Data")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        showingImport = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.orange)
                            Text("Import from CSV")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        showingCleanupConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.purple)
                            Text("Clean Up Duplicate Foods")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        fixLegacyImportNutrition()
                    } label: {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(.green)
                            Text("Fix Legacy Import Nutrition")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        fixLegacyImportDates()
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.orange)
                            Text("Fix Legacy Import Dates")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        debugCentrumData()
                    } label: {
                        HStack {
                            Image(systemName: "ladybug")
                                .foregroundStyle(.blue)
                            Text("Debug Centrum Data")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        debugVegetableJuice()
                    } label: {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundStyle(.red)
                            Text("Debug Vegetable Juice")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        fixVegetableJuice()
                    } label: {
                        HStack {
                            Image(systemName: "wrench.fill")
                                .foregroundStyle(.orange)
                            Text("Fix Vegetable Juice")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete All Food Logs")
                        }
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("You have \(allLogs.count) food logs and \(foodItemsCount) food items")
                        .font(.caption)
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadPreferences()
            }
            .sheet(isPresented: $showingImport) {
                LoseItImportView()
            }
            .sheet(isPresented: $showingExport) {
                DataExportView()
            }
            .alert("Delete All Food Logs?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all \(allLogs.count) food logs and \(foodItemsCount) food items. This cannot be undone.")
            }
            .alert("Clean Up Duplicates?", isPresented: $showingCleanupConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clean Up", role: .destructive) {
                    cleanUpDuplicates()
                }
            } message: {
                Text("This will merge duplicate food items with the same barcode. All food logs will be updated to point to a single entry.")
            }
            .alert("Cleanup Complete", isPresented: $showingCleanupResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(cleanupResultMessage)
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Deleting all data...")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            if !deleteProgress.isEmpty {
                                Text(deleteProgress)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(40)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(20)
                    }
                }
            }
        }
    }
    
    private func loadPreferences() {
        if let prefs = preferences.first {
            pinnedNutrient = prefs.pinnedNutrient.flatMap { Nutrient(rawValue: $0) }
            showMacroBalance = prefs.showMacroBalanceTile ?? true // Default to true if nil
            goals = prefs.goals
        } else {
            // Create default preferences
            let newPrefs = UserPreferences()
            modelContext.insert(newPrefs)
            try? modelContext.save()
        }
    }
    
    private func updatePreferences() {
        if let prefs = preferences.first {
            prefs.pinnedNutrient = pinnedNutrient?.rawValue
            prefs.showMacroBalanceTile = showMacroBalance
            prefs.goals = goals
            try? modelContext.save()
        } else {
            let newPrefs = UserPreferences(
                pinnedNutrient: pinnedNutrient?.rawValue,
                showMacroBalanceTile: showMacroBalance
            )
            newPrefs.goals = goals
            modelContext.insert(newPrefs)
            try? modelContext.save()
        }
    }
    
    private func defaultGoalValue(for nutrient: Nutrient) -> Double {
        switch nutrient {
        case .calories: return 2000
        case .protein: return 150
        case .carbs: return 250
        case .fat: return 65
        case .fiber: return 30
        case .sugar: return 50
        case .sodium: return 2300
        case .saturatedFat: return 20
        case .cholesterol: return 300
        case .potassium: return 3500
        case .calcium: return 1000
        case .iron: return 18
        case .vitaminC: return 90
        case .vitaminD: return 20
        case .caffeine: return 400
        default: return 100
        }
    }
    
    private func deleteAllData() {
        isDeleting = true
        deleteProgress = "Preparing deletion..."
        
        Task {
            // Perform deletion on background thread
            await Task.detached(priority: .userInitiated) {
                // Create a new model context for background work
                let container = modelContext.container
                let backgroundContext = ModelContext(container)
                
                // Step 1: Delete all food logs (no relationships)
                await MainActor.run {
                    deleteProgress = "Deleting food logs..."
                }
                
                let logsDescriptor = FetchDescriptor<FoodLog>()
                if let logs = try? backgroundContext.fetch(logsDescriptor) {
                    let total = logs.count
                    await MainActor.run {
                        deleteProgress = "Deleting \(total) food logs..."
                    }
                    
                    // Delete all at once
                    for log in logs {
                        backgroundContext.delete(log)
                    }
                    
                    // Single save for all logs
                    try? backgroundContext.save()
                }
                
                // Step 2: Delete all serving sizes
                await MainActor.run {
                    deleteProgress = "Deleting serving sizes..."
                }
                
                let servingsDescriptor = FetchDescriptor<ServingSize>()
                if let servings = try? backgroundContext.fetch(servingsDescriptor) {
                    let total = servings.count
                    await MainActor.run {
                        deleteProgress = "Deleting \(total) serving sizes..."
                    }
                    
                    for serving in servings {
                        backgroundContext.delete(serving)
                    }
                    
                    try? backgroundContext.save()
                }
                
                // Step 3: Delete all food items
                await MainActor.run {
                    deleteProgress = "Deleting food items..."
                }
                
                let foodsDescriptor = FetchDescriptor<FoodItem>()
                if let foods = try? backgroundContext.fetch(foodsDescriptor) {
                    let total = foods.count
                    await MainActor.run {
                        deleteProgress = "Deleting \(total) food items..."
                    }
                    
                    for food in foods {
                        backgroundContext.delete(food)
                    }
                    
                    try? backgroundContext.save()
                }
                
                await MainActor.run {
                    deleteProgress = "Finalizing..."
                }
            }.value
            
            // Back on main thread
            await MainActor.run {
                isDeleting = false
                deleteProgress = ""
            }
        }
    }
    
    private func cleanUpDuplicates() {
        var removedCount = 0
        var mergedGroups = 0
        
        // Create a fresh fetch to get current state
        let descriptor = FetchDescriptor<FoodItem>()
        guard let currentFoodItems = try? modelContext.fetch(descriptor) else {
            cleanupResultMessage = "Failed to fetch food items."
            showingCleanupResult = true
            return
        }
        
        // Group foods by barcode
        let groupedByBarcode = Dictionary(grouping: currentFoodItems.filter { $0.barcode != nil && !$0.barcode!.isEmpty }) { $0.barcode! }
        
        // Process each group with duplicates
        for (barcode, duplicates) in groupedByBarcode where duplicates.count > 1 {
            mergedGroups += 1
            
            // Keep the most recently added item
            let keeper = duplicates.sorted { (a, b) in
                return a.dateAdded > b.dateAdded
            }.first!
            
            // Get all logs fresh from the database
            let logDescriptor = FetchDescriptor<FoodLog>()
            guard let currentLogs = try? modelContext.fetch(logDescriptor) else { continue }
            
            // Update all logs pointing to duplicates to point to the keeper
            for duplicate in duplicates where duplicate.id != keeper.id {
                // Find all logs using this duplicate
                let logsUsingDuplicate = currentLogs.filter { $0.foodItem?.id == duplicate.id }
                
                // Point them to the keeper
                for log in logsUsingDuplicate {
                    log.foodItem = keeper
                }
                
                // Delete the duplicate
                modelContext.delete(duplicate)
                removedCount += 1
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            
            // Show result
            if removedCount > 0 {
                cleanupResultMessage = "Removed \(removedCount) duplicate food items across \(mergedGroups) groups."
            } else {
                cleanupResultMessage = "No duplicate food items found."
            }
        } catch {
            cleanupResultMessage = "Error during cleanup: \(error.localizedDescription)"
        }
        
        showingCleanupResult = true
    }
    
    private func fixLegacyImportNutrition() {
        print("🔧 Starting legacy import nutrition fix...")
        
        // Get all food items
        let descriptor = FetchDescriptor<FoodItem>()
        guard let allFoods = try? modelContext.fetch(descriptor) else {
            print("❌ Failed to fetch foods")
            return
        }
        
        var fixed = 0
        var skipped = 0
        
        for food in allFoods {
            // Only fix foods from CSV import that have missing nutrition
            // (either 0 calories OR missing micronutrients)
            let needsFix = food.source.contains("CSV Import") && (
                food.calories == 0.0 ||
                food.vitaminA == nil ||
                food.vitaminC == nil ||
                food.calcium == nil
            )
            
            guard needsFix else {
                skipped += 1
                continue
            }
            
            // Get all logs for this food
            let foodId = food.id
            let logDescriptor = FetchDescriptor<FoodLog>(
                predicate: #Predicate { log in
                    log.foodItem?.id == foodId
                }
            )
            
            guard let logs = try? modelContext.fetch(logDescriptor), !logs.isEmpty else {
                print("⚠️ No logs found for \(food.name)")
                continue
            }
            
            // Find the BEST log to use as base:
            // 1. Prefer logs that have micronutrient data (not just macros)
            // 2. Among those, prefer quantity closest to 1.0
            let logsWithMicronutrients = logs.filter { log in
                (log.vitaminAAtLogTime ?? 0) > 0 ||
                (log.vitaminCAtLogTime ?? 0) > 0 ||
                (log.calciumAtLogTime ?? 0) > 0 ||
                (log.ironAtLogTime ?? 0) > 0
            }
            
            let bestLog: FoodLog?
            if !logsWithMicronutrients.isEmpty {
                // Use log with micronutrients, preferring quantity close to 1.0
                bestLog = logsWithMicronutrients.min { abs($0.quantity - 1.0) < abs($1.quantity - 1.0) }
            } else {
                // Fall back to any log with quantity close to 1.0
                bestLog = logs.min { abs($0.quantity - 1.0) < abs($1.quantity - 1.0) }
            }
            
            if let baseLog = bestLog {
                // Calculate per-serving values by dividing by quantity
                let divisor = baseLog.quantity > 0 ? baseLog.quantity : 1.0
                
                // Macros
                food.calories = baseLog.caloriesAtLogTime / divisor
                food.protein = baseLog.proteinAtLogTime / divisor
                food.carbs = baseLog.carbsAtLogTime / divisor
                food.fat = baseLog.fatAtLogTime / divisor
                
                // Fats
                food.fiber = baseLog.fiberAtLogTime.map { $0 / divisor }
                food.sugar = baseLog.sugarAtLogTime.map { $0 / divisor }
                food.saturatedFat = baseLog.saturatedFatAtLogTime.map { $0 / divisor }
                food.transFat = baseLog.transFatAtLogTime.map { $0 / divisor }
                food.monounsaturatedFat = baseLog.monounsaturatedFatAtLogTime.map { $0 / divisor }
                food.polyunsaturatedFat = baseLog.polyunsaturatedFatAtLogTime.map { $0 / divisor }
                
                // Minerals
                food.sodium = baseLog.sodiumAtLogTime.map { $0 / divisor }
                food.cholesterol = baseLog.cholesterolAtLogTime.map { $0 / divisor }
                food.potassium = baseLog.potassiumAtLogTime.map { $0 / divisor }
                food.calcium = baseLog.calciumAtLogTime.map { $0 / divisor }
                food.iron = baseLog.ironAtLogTime.map { $0 / divisor }
                food.magnesium = baseLog.magnesiumAtLogTime.map { $0 / divisor }
                food.zinc = baseLog.zincAtLogTime.map { $0 / divisor }
                
                // Vitamins
                food.vitaminA = baseLog.vitaminAAtLogTime.map { $0 / divisor }
                food.vitaminC = baseLog.vitaminCAtLogTime.map { $0 / divisor }
                food.vitaminD = baseLog.vitaminDAtLogTime.map { $0 / divisor }
                food.vitaminE = baseLog.vitaminEAtLogTime.map { $0 / divisor }
                food.vitaminK = baseLog.vitaminKAtLogTime.map { $0 / divisor }
                food.vitaminB6 = baseLog.vitaminB6AtLogTime.map { $0 / divisor }
                food.vitaminB12 = baseLog.vitaminB12AtLogTime.map { $0 / divisor }
                food.folate = baseLog.folateAtLogTime.map { $0 / divisor }
                food.choline = baseLog.cholineAtLogTime.map { $0 / divisor }
                
                // Other
                food.caffeine = baseLog.caffeineAtLogTime.map { $0 / divisor }
                
                print("✅ Fixed \(food.name): \(Int(food.calories)) cal per serving")
                fixed += 1
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            let message = "Fixed \(fixed) food items. Skipped \(skipped) items that didn't need fixing."
            print("✅ \(message)")
            
            // Show alert
            cleanupResultMessage = message
            showingCleanupResult = true
        } catch {
            cleanupResultMessage = "Error fixing nutrition: \(error.localizedDescription)"
            showingCleanupResult = true
        }
    }
    
    private func fixLegacyImportDates() {
        print("🔧 Starting legacy import date fix...")
        
        // Get all food logs
        let descriptor = FetchDescriptor<FoodLog>()
        guard let allLogs = try? modelContext.fetch(descriptor) else {
            print("❌ Failed to fetch logs")
            return
        }
        
        var fixed = 0
        var skipped = 0
        
        for log in allLogs {
            // Check if timestamp is in the wrong century (before year 1000)
            let components = Calendar.current.dateComponents([.year], from: log.timestamp)
            guard let year = components.year, year < 1000 else {
                skipped += 1
                continue
            }
            
            // Add 2000 years to the date
            if let fixedDate = Calendar.current.date(byAdding: .year, value: 2000, to: log.timestamp) {
                log.timestamp = fixedDate
                fixed += 1
                
                if fixed % 100 == 0 {
                    print("   Fixed \(fixed) logs so far...")
                }
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            let message = "Fixed \(fixed) food log dates by adding 2000 years. Skipped \(skipped) logs with correct dates."
            print("✅ \(message)")
            
            // Show alert
            cleanupResultMessage = message
            showingCleanupResult = true
        } catch {
            cleanupResultMessage = "Error fixing dates: \(error.localizedDescription)"
            showingCleanupResult = true
        }
    }
    
    private func debugCentrumData() {
        print("🐛 DEBUG: Looking for Centrum...")
        
        // Find Centrum food
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.name.contains("Centrum") }
        )
        
        guard let centrumFoods = try? modelContext.fetch(descriptor), let centrum = centrumFoods.first else {
            print("❌ No Centrum food found")
            cleanupResultMessage = "No Centrum food found in database"
            showingCleanupResult = true
            return
        }
        
        print("✅ Found: \(centrum.name) (brand: \(centrum.brand ?? "none"))")
        print("   Source: \(centrum.source)")
        print("   Mode: \(centrum.nutritionMode)")
        print("   FoodItem nutrition:")
        print("     Calories: \(centrum.calories)")
        print("     Protein: \(centrum.protein)")
        print("     Carbs: \(centrum.carbs)")
        print("     Fat: \(centrum.fat)")
        print("     Vitamin A: \(centrum.vitaminA?.description ?? "nil")")
        print("     Vitamin C: \(centrum.vitaminC?.description ?? "nil")")
        print("     Vitamin D: \(centrum.vitaminD?.description ?? "nil")")
        print("     Calcium: \(centrum.calcium?.description ?? "nil")")
        print("     Iron: \(centrum.iron?.description ?? "nil")")
        
        // Find logs for Centrum
        let centrumId = centrum.id
        let logDescriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.foodItem?.id == centrumId
            }
        )
        
        guard let logs = try? modelContext.fetch(logDescriptor), !logs.isEmpty else {
            print("❌ No logs found for Centrum")
            cleanupResultMessage = "Centrum FoodItem found but has no logs"
            showingCleanupResult = true
            return
        }
        
        print("   Found \(logs.count) logs for Centrum:")
        for (idx, log) in logs.prefix(3).enumerated() {
            print("   Log \(idx + 1): qty=\(log.quantity), serving=\(log.servingSize?.label ?? "nil")")
            print("     AtLogTime nutrition:")
            print("       Calories: \(log.caloriesAtLogTime)")
            print("       Protein: \(log.proteinAtLogTime)")
            print("       Vitamin A: \(log.vitaminAAtLogTime?.description ?? "nil")")
            print("       Vitamin C: \(log.vitaminCAtLogTime?.description ?? "nil")")
            print("       Vitamin D: \(log.vitaminDAtLogTime?.description ?? "nil")")
            print("       Calcium: \(log.calciumAtLogTime?.description ?? "nil")")
            print("       Iron: \(log.ironAtLogTime?.description ?? "nil")")
        }
        
        cleanupResultMessage = "Check Xcode console for Centrum debug output"
        showingCleanupResult = true
    }
    
    private func debugVegetableJuice() {
        print("🐛 DEBUG: Looking for vegetable juice...")
        
        // Find vegetable juice food
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.name.contains("Vegetable Juice") }
        )
        
        guard let foods = try? modelContext.fetch(descriptor), let food = foods.first else {
            print("❌ No vegetable juice food found")
            cleanupResultMessage = "No vegetable juice food found in database"
            showingCleanupResult = true
            return
        }
        
        print("✅ Found: \(food.name) (brand: \(food.brand ?? "none"))")
        print("   Source: \(food.source)")
        print("   Mode: \(food.nutritionMode)")
        print("   FoodItem nutrition:")
        print("     Calories: \(food.calories)")
        print("     Protein: \(food.protein)")
        print("     Carbs: \(food.carbs)")
        print("     Fat: \(food.fat)")
        
        print("\n   Serving Sizes (\(food.servingSizes.count)):")
        for (idx, serving) in food.servingSizes.enumerated() {
            print("     [\(idx)] label='\(serving.label)', gramWeight=\(serving.gramWeight?.description ?? "nil"), isDefault=\(serving.isDefault)")
        }
        
        // Find logs for this food
        let foodId = food.id
        let logDescriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.foodItem?.id == foodId
            }
        )
        
        guard let logs = try? modelContext.fetch(logDescriptor), !logs.isEmpty else {
            print("❌ No logs found for vegetable juice")
            cleanupResultMessage = "Vegetable juice FoodItem found but has no logs"
            showingCleanupResult = true
            return
        }
        
        print("\n   Found \(logs.count) logs for vegetable juice:")
        for (idx, log) in logs.prefix(5).enumerated() {
            print("   Log \(idx + 1): qty=\(log.quantity), serving=\(log.servingSize?.label ?? "nil")")
            print("     AtLogTime nutrition:")
            print("       Calories: \(log.caloriesAtLogTime)")
            print("       Protein: \(log.proteinAtLogTime)")
        }
        
        // Analyze the issue
        print("\n🔍 ANALYSIS:")
        if let defaultServing = food.defaultServing {
            print("   Default serving label: '\(defaultServing.label)'")
            print("   Default serving grams: \(defaultServing.gramWeight?.description ?? "nil")")
            
            if defaultServing.label == "oz" && defaultServing.gramWeight == nil {
                print("   ⚠️ PROBLEM DETECTED: Serving label is just 'oz' without quantity or gram weight")
                print("   🔧 This needs to be fixed. The serving should be something like '4 fl oz' or '8 fl oz'")
                print("   💡 Looking at logs to determine correct serving size...")
                
                // Look at the most common quantity to infer the correct serving
                let quantities = logs.map { $0.quantity }
                let avgQuantity = quantities.reduce(0, +) / Double(quantities.count)
                print("   📊 Average log quantity: \(avgQuantity)")
                print("   💡 This suggests the base serving might be '\(Int(avgQuantity)) fl oz'")
            }
        }
        
        cleanupResultMessage = "Check Xcode console for vegetable juice debug output"
        showingCleanupResult = true
    }
    
    private func fixVegetableJuice() {
        print("🔧 FIXING: Vegetable juice data...")
        
        // Find vegetable juice food
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.name.contains("Vegetable Juice") }
        )
        
        guard let foods = try? modelContext.fetch(descriptor), let food = foods.first else {
            print("❌ No vegetable juice food found")
            cleanupResultMessage = "No vegetable juice food found to fix"
            showingCleanupResult = true
            return
        }
        
        print("✅ Found: \(food.name)")
        print("   BEFORE FIX:")
        print("     Calories: \(food.calories)")
        print("     Protein: \(food.protein)")
        print("     Carbs: \(food.carbs)")
        print("     Serving: \(food.defaultServing?.label ?? "nil"), grams: \(food.defaultServing?.gramWeight?.description ?? "nil")")
        
        // The current values (24 cal, 1.1 prot, 4.8 carbs) are for 4 oz
        // We need to divide by 4 to get per-1-oz values
        let divisor = 4.0
        food.calories = food.calories / divisor
        food.protein = food.protein / divisor
        food.carbs = food.carbs / divisor
        food.fat = food.fat / divisor
        
        // Update optional nutrients if present
        if let fiber = food.fiber {
            food.fiber = fiber / divisor
        }
        if let sugar = food.sugar {
            food.sugar = sugar / divisor
        }
        if let sodium = food.sodium {
            food.sodium = sodium / divisor
        }
        
        // Fix the serving size
        if let defaultServing = food.defaultServing {
            defaultServing.label = "fl oz"  // Just "fl oz" so it displays as "4 fl oz" not "4 1 fl oz"
            defaultServing.gramWeight = 30.0  // 1 fl oz ≈ 30g for liquids
            print("   Updated existing serving")
        } else {
            // Create new default serving if somehow missing
            let newServing = ServingSize(
                label: "fl oz",
                gramWeight: 30.0,
                isDefault: true,
                sortOrder: 0
            )
            newServing.foodItem = food
            modelContext.insert(newServing)
            food.servingSizes.append(newServing)
            print("   Created new default serving")
        }
        
        print("   AFTER FIX:")
        print("     Calories: \(food.calories)")
        print("     Protein: \(food.protein)")
        print("     Carbs: \(food.carbs)")
        print("     Serving: \(food.defaultServing?.label ?? "nil"), grams: \(food.defaultServing?.gramWeight?.description ?? "nil")")
        
        // Now fix all existing logs - they have old frozen nutrition that needs updating
        let foodId = food.id
        let logDescriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.foodItem?.id == foodId
            }
        )
        
        if let logs = try? modelContext.fetch(logDescriptor) {
            print("\n   Fixing \(logs.count) existing logs...")
            for log in logs {
                // Recalculate frozen nutrition based on new per-oz values
                // Old: quantity=4, calories=24 (frozen as 24 total)
                // New: quantity=4, calories per oz=6, so 4*6=24 total
                let qty = log.quantity
                log.caloriesAtLogTime = food.calories * qty
                log.proteinAtLogTime = food.protein * qty
                log.carbsAtLogTime = food.carbs * qty
                log.fatAtLogTime = food.fat * qty
                
                if let fiber = food.fiber {
                    log.fiberAtLogTime = fiber * qty
                }
                if let sugar = food.sugar {
                    log.sugarAtLogTime = sugar * qty
                }
                if let sodium = food.sodium {
                    log.sodiumAtLogTime = sodium * qty
                }
                
                print("     Updated log with qty=\(qty): calories=\(log.caloriesAtLogTime)")
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("✅ Fixed vegetable juice successfully!")
            print("   Now: quantity=4 will show '4 Fluid Ounces' and calculate \(food.calories * 4) calories")
            
            cleanupResultMessage = "Fixed vegetable juice!\nCalories: \(Int(food.calories * 4)) per 4 oz (was showing 96)\nServing: fl oz (30g)\nUpdated all existing logs"
            showingCleanupResult = true
        } catch {
            print("❌ Failed to save: \(error)")
            cleanupResultMessage = "Error saving fix: \(error.localizedDescription)"
            showingCleanupResult = true
        }
    }
    
}
// MARK: - Goal Row Component

struct GoalRow: View {
    let nutrient: Nutrient
    @Binding var goals: [String: NutrientGoal]
    let onUpdate: () -> Void
    
    @State private var showingEditor = false
    
    private var hasGoal: Bool {
        goals[nutrient.rawValue] != nil
    }
    
    var body: some View {
        if hasGoal, let goal = goals[nutrient.rawValue] {
            Button {
                showingEditor = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nutrient.rawValue)
                            .foregroundStyle(.primary)
                        Text(goalDescription(for: goal))
                            .font(.caption)
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color("TextTertiary"))
                }
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack {
                    GoalEditorView(
                        nutrient: nutrient,
                        goal: goal,
                        onSave: { newGoal in
                            goals[nutrient.rawValue] = newGoal
                            onUpdate()
                        },
                        onDelete: {
                            goals.removeValue(forKey: nutrient.rawValue)
                            onUpdate()
                        }
                    )
                }
            }
        } else {
            Button {
                let defaultValue = defaultGoalValue(for: nutrient)
                let defaultGoal = NutrientGoal(
                    targetValue: defaultValue,
                    goalType: nutrient.defaultGoalType,
                    rangeMax: (nutrient.defaultGoalType == .range) ? defaultValue * 1.1 : nil
                )
                goals[nutrient.rawValue] = defaultGoal
                onUpdate()
            } label: {
                HStack {
                    Text(nutrient.rawValue)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Set Goal")
                        .font(.subheadline)
                        .foregroundStyle(Color("BrandAccent"))
                }
            }
        }
    }
    
    private func goalDescription(for goal: NutrientGoal) -> String {
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
    
    private func defaultGoalValue(for nutrient: Nutrient) -> Double {
        switch nutrient {
        case .calories: return 2000
        case .protein: return 150
        case .carbs: return 250
        case .fat: return 65
        case .fiber: return 30
        case .sugar: return 50
        case .sodium: return 2300
        case .saturatedFat: return 20
        case .cholesterol: return 300
        case .potassium: return 3500
        case .calcium: return 1000
        case .iron: return 18
        case .vitaminC: return 90
        case .vitaminD: return 20
        case .caffeine: return 400
        default: return 100
        }
    }
}


