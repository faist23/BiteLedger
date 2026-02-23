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
    @State private var trackedGoalNutrient: Nutrient?
    @State private var goals: [String: NutrientGoal] = [:]
    @State private var showingGoalEditor = false
    @State private var editingNutrient: Nutrient?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                    Text("Choose an additional nutrient to display on the dashboard (5th tile). Calories, Protein, Carbs, and Fat are always shown.")
                }
                
                Section {
                    Picker("Track Goal For", selection: $trackedGoalNutrient) {
                        Text("None").tag(nil as Nutrient?)
                        ForEach(Nutrient.allCases) { nutrient in
                            Text(nutrient.rawValue).tag(nutrient as Nutrient?)
                        }
                    }
                    .onChange(of: trackedGoalNutrient) { _, _ in
                        updatePreferences()
                    }
                    
                    if let tracked = trackedGoalNutrient {
                        if let goal = goals[tracked.rawValue] {
                            NavigationLink {
                                GoalEditorView(
                                    nutrient: tracked,
                                    goal: goal,
                                    onSave: { newGoal in
                                        goals[tracked.rawValue] = newGoal
                                        updatePreferences()
                                    },
                                    onDelete: {
                                        goals.removeValue(forKey: tracked.rawValue)
                                        if trackedGoalNutrient?.rawValue == tracked.rawValue {
                                            trackedGoalNutrient = nil
                                        }
                                        updatePreferences()
                                    }
                                )
                            } label: {
                                HStack {
                                    Text("\(tracked.rawValue) Goal")
                                    Spacer()
                                    Text("\(Int(goal.targetValue)) \(tracked.unit)")
                                        .foregroundStyle(Color("TextSecondary"))
                                }
                            }
                        } else {
                            Button("Set \(tracked.rawValue) Goal") {
                                let defaultGoal = NutrientGoal(
                                    targetValue: defaultGoalValue(for: tracked),
                                    goalType: tracked.defaultGoalType,
                                    rangeMax: nil
                                )
                                goals[tracked.rawValue] = defaultGoal
                                updatePreferences()
                            }
                        }
                    }
                } header: {
                    Text("Goals")
                } footer: {
                    Text("Set a goal for one nutrient to show a progress bar on the dashboard.")
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
            trackedGoalNutrient = prefs.trackedGoalNutrient.flatMap { Nutrient(rawValue: $0) }
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
            prefs.trackedGoalNutrient = trackedGoalNutrient?.rawValue
            prefs.goals = goals
            try? modelContext.save()
        } else {
            let newPrefs = UserPreferences(
                pinnedNutrient: pinnedNutrient?.rawValue,
                trackedGoalNutrient: trackedGoalNutrient?.rawValue
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
