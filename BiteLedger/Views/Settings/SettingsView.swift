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


