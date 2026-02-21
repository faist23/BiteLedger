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
    
    @State private var showingImport = false
    @State private var showingExport = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
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
