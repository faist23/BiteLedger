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
    @Query private var allFoodItems: [FoodItem]
    @Query private var preferences: [UserPreferences]
    
    @State private var showingImport = false
    @State private var showingExport = false
    @State private var showingDeleteConfirmation = false
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
                    Text("You have \(allLogs.count) food logs and \(allFoodItems.count) food items")
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
                Text("This will permanently delete all \(allLogs.count) food logs and \(allFoodItems.count) food items. This cannot be undone.")
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
        // Delete all food logs
        for log in allLogs {
            modelContext.delete(log)
        }
        
        // Delete all food items
        for item in allFoodItems {
            modelContext.delete(item)
        }
        
        // Save changes
        try? modelContext.save()
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

