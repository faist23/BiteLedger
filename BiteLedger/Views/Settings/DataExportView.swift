//
//  DataExportView.swift
//  BiteLedger
//
//  Created by Claude on 2/20/26.
//

import SwiftUI
import SwiftData

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \FoodLog.timestamp, order: .reverse) private var allLogs: [FoodLog]
    
    @State private var exportRange: ExportRange = .all
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    enum ExportRange: String, CaseIterable, Identifiable {
        case all = "All Data"
        case lastWeek = "Last 7 Days"
        case lastMonth = "Last 30 Days"
        case lastThreeMonths = "Last 3 Months"
        case custom = "Custom Date Range"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header icon
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text("Export Your Data")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Export your food logs as a CSV file")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Export options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Date Range:")
                        .font(.headline)
                    
                    Picker("Range", selection: $exportRange) {
                        ForEach(ExportRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if exportRange == .custom {
                        VStack(spacing: 12) {
                            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Stats
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.orange)
                        Text("\(filteredLogsCount) entries will be exported")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Export button
                Button {
                    exportData()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                        }
                        Text(isExporting ? "Exporting..." : "Export to CSV")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isExporting ? Color.gray : Color.green)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isExporting || filteredLogsCount == 0)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var filteredLogsCount: Int {
        getFilteredLogs().count
    }
    
    private func getFilteredLogs() -> [FoodLog] {
        let calendar = Calendar.current
        let now = Date()
        
        switch exportRange {
        case .all:
            return allLogs
        case .lastWeek:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return allLogs.filter { $0.timestamp >= weekAgo }
        case .lastMonth:
            let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return allLogs.filter { $0.timestamp >= monthAgo }
        case .lastThreeMonths:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return allLogs.filter { $0.timestamp >= threeMonthsAgo }
        case .custom:
            let startOfDay = calendar.startOfDay(for: startDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
            return allLogs.filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
        }
    }
    
    private func exportData() {
        isExporting = true
        errorMessage = nil
        
        Task {
            do {
                let logs = getFilteredLogs()
                let fileURL = try DataExporter.exportToCSV(logs: logs)
                
                await MainActor.run {
                    exportedFileURL = fileURL
                    isExporting = false
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isExporting = false
                    showingError = true
                }
            }
        }
    }
}

// Share sheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DataExportView()
}
