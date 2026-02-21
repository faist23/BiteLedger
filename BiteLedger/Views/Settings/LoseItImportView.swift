//
//  LoseItImportView.swift
//  BiteLedger
//
//  Created by Claude on 2/20/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LoseItImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var isImporting = false
    @State private var showingFilePicker = false
    @State private var importResult: LoseItImporter.ImportResult?
    @State private var errorMessage: String?
    @State private var showingResult = false
    @State private var showingErrorDetails = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header icon
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                    .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text("Import Food Logs")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Import your food logs from a CSV file")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Supported Formats:")
                        .font(.headline)
                    
                    InstructionRow(number: "✓", text: "BiteLedger CSV exports")
                    InstructionRow(number: "✓", text: "LoseIt CSV exports")
                    
                    Text("To export from LoseIt:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    
                    Text("Settings > Export Data > CSV")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Import button
                Button {
                    showingFilePicker = true
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "doc.fill")
                        }
                        Text(isImporting ? "Importing..." : "Select CSV File")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isImporting ? Color.gray : Color.orange)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isImporting)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import Complete", isPresented: $showingResult) {
                Button("OK") {
                    if importResult?.successCount ?? 0 > 0 {
                        dismiss()
                    }
                }
                if let result = importResult, !result.errors.isEmpty {
                    Button("View Errors") {
                        showingErrorDetails = true
                    }
                }
            } message: {
                if let result = importResult {
                    Text("Successfully imported \(result.successCount) entries.\nFailed: \(result.failedCount)")
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                }
            }
            .sheet(isPresented: $showingErrorDetails) {
                ErrorDetailsView(errors: importResult?.errors ?? [])
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importCSVFile(url)
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingResult = true
        }
    }
    
    private func importCSVFile(_ url: URL) {
        isImporting = true
        errorMessage = nil
        importResult = nil
        
        Task {
            do {
                // Get access to the file
                let gotAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if gotAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let result = try await LoseItImporter.importCSV(from: url, modelContext: modelContext)
                
                await MainActor.run {
                    importResult = result
                    isImporting = false
                    showingResult = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                    showingResult = true
                }
            }
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct ErrorDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let errors: [String]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if errors.isEmpty {
                        Text("No errors to display")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(errors.enumerated()), id: \.offset) { index, error in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Error \(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                                
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Import Errors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LoseItImportView()
}
