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
    @State private var showDailyGoal = false
    @State private var dailyCalorieGoal: Double = 2000
    @State private var trackingMetric: TrackingMetric = .calories
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tracking Metric", selection: $trackingMetric) {
                        ForEach(TrackingMetric.allCases, id: \.self) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .onChange(of: trackingMetric) { _, newValue in
                        updatePreferences()
                    }
                    
                    Toggle("Show Daily Goal", isOn: $showDailyGoal)
                        .onChange(of: showDailyGoal) { _, newValue in
                            updatePreferences()
                        }
                    
                    if showDailyGoal {
                        HStack {
                            Text("Daily Calorie Goal")
                            Spacer()
                            TextField("Goal", value: $dailyCalorieGoal, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .onChange(of: dailyCalorieGoal) { _, newValue in
                                    updatePreferences()
                                }
                        }
                    }
                } header: {
                    Text("Tracking")
                } footer: {
                    Text("Choose which metric to track on the home screen. Enable daily goal to show a progress bar.")
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
            showDailyGoal = prefs.showDailyGoal
            dailyCalorieGoal = prefs.dailyCalorieGoal ?? 2000
            trackingMetric = prefs.trackingMetric
        } else {
            // Create default preferences
            let newPrefs = UserPreferences()
            modelContext.insert(newPrefs)
            try? modelContext.save()
        }
    }
    
    private func updatePreferences() {
        if let prefs = preferences.first {
            prefs.showDailyGoal = showDailyGoal
            prefs.dailyCalorieGoal = dailyCalorieGoal
            prefs.trackingMetric = trackingMetric
            try? modelContext.save()
        } else {
            let newPrefs = UserPreferences(
                dailyCalorieGoal: dailyCalorieGoal,
                trackingMetric: trackingMetric,
                showDailyGoal: showDailyGoal
            )
            modelContext.insert(newPrefs)
            try? modelContext.save()
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
