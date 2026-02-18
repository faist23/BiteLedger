//
//  MealItemSelectionView.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData

/// Select items from a previous meal to add to current meal
struct MealItemSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let sourceLogs: [FoodLog] // The meal we're copying from
    let targetMealType: MealType // The meal we're adding to
    let onAdd: ([FoodLog]) -> Void
    
    @State private var selectedLogs: Set<UUID> = []
    
    private var totalCalories: Double {
        sourceLogs.filter { selectedLogs.contains($0.id) }
            .reduce(0) { $0 + $1.calories }
    }
    
    private var selectedCount: Int {
        selectedLogs.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instruction text
                Text("Add selected foods from this meal to my log:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                
                // List of items with checkboxes
                List {
                    ForEach(sourceLogs) { log in
                        if let foodItem = log.foodItem {
                            HStack(spacing: 12) {
                                // Checkbox
                                Image(systemName: selectedLogs.contains(log.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selectedLogs.contains(log.id) ? .orange : .gray)
                                
                                // Food icon/image
                                if let imageUrl = foodItem.imageURL, let url = URL(string: imageUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.quaternary)
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Image(systemName: "fork.knife")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                }
                                
                                // Food info
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(foodItem.name)
                                        .font(.subheadline)
                                    Text(log.servingDisplayText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // Calories
                                Text("\(Int(log.calories))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(for: log.id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                
                // Bottom summary
                HStack {
                    Text("\(selectedCount) Selected")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("Calories: \(Int(totalCalories))")
                        .font(.headline)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
            }
            .navigationTitle("Add Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addSelectedItems()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .disabled(selectedLogs.isEmpty)
                }
            }
            .onAppear {
                // Select all items by default
                selectedLogs = Set(sourceLogs.map { $0.id })
            }
        }
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedLogs.contains(id) {
            selectedLogs.remove(id)
        } else {
            selectedLogs.insert(id)
        }
    }
    
    private func addSelectedItems() {
        let logsToAdd = sourceLogs.filter { selectedLogs.contains($0.id) }
        onAdd(logsToAdd)
        dismiss()
    }
}
