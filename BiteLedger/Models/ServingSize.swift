//
//  ServingSize.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/25/26.
//

import SwiftData
import Foundation

// MARK: - ServingSize

@Model
final class ServingSize {

    // MARK: Identity
    // CloudKit requires all stored properties to be optional or have default values.
    var id: UUID = UUID()
    var dateAdded: Date = Date()

    // MARK: Display
    /// Human-readable label shown in the UI.
    /// Examples: "1 cup", "1 medium banana", "1 sandwich", "2 cookies", "1 slice"
    /// The quantity is baked into the label — do NOT store quantity separately.
    var label: String = ""

    /// Weight in grams for this serving. nil when unknown or not applicable.
    ///
    /// Rules:
    ///   - Set for per100g foods when gram weight is known from a data source
    ///   - Always nil for perServing foods
    ///   - Never estimated using generic density tables
    ///   - Never faked — if you don't know it, store nil
    var gramWeight: Double?

    /// True for the serving shown by default in search results and log pickers.
    /// Exactly one ServingSize per FoodItem should have isDefault = true.
    var isDefault: Bool = false

    /// Controls display order in serving pickers. Lower = shown first.
    var sortOrder: Int = 0

    // MARK: Relationships
    var foodItem: FoodItem?

    @Relationship(deleteRule: .nullify) var foodLogs: [FoodLog] = []

    // MARK: Init
    init(
        id: UUID = UUID(),
        label: String,
        gramWeight: Double? = nil,
        isDefault: Bool = false,
        sortOrder: Int = 0,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.gramWeight = gramWeight
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.dateAdded = dateAdded
    }

    // MARK: Computed

    /// Supplementary display string showing gram weight if known.
    /// Example: "1 cup (42g)" or just "1 sandwich"
    var displayLabel: String {
        if let grams = gramWeight {
            let formatted = grams.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(grams))
                : String(format: "%.1f", grams)
            return "\(label) (\(formatted)g)"
        }
        return label
    }
}
