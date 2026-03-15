//
//  ServingConversion.swift
//  BiteLedger
//
//  Created by Craig Faist on 3/14/26.
//

import SwiftData
import Foundation

// MARK: - ServingConversion

/// A single unit → gram mapping for a CanonicalFood.
///
/// Examples for "Peanut Butter":
///   unit="tbsp",  gramsPerUnit=16.0
///   unit="cup",   gramsPerUnit=258.0
///   unit="tsp",   gramsPerUnit=5.4
///
/// `gramsPerUnit` is always the weight of exactly 1 unit (not `amount` units).
/// To get grams for a serving: grams = amount × gramsPerUnit
@Model
final class ServingConversion {

    // MARK: Identity
    var id: UUID = UUID()

    /// Unit abbreviation matched against ServingSize.unit (e.g. "tbsp", "cup", "oz").
    var unit: String = ""

    /// Grams per 1 of this unit for the parent CanonicalFood.
    var gramsPerUnit: Double = 1.0

    // MARK: Relationships
    var canonicalFood: CanonicalFood?

    // MARK: Init

    init(unit: String, gramsPerUnit: Double) {
        self.unit = unit
        self.gramsPerUnit = gramsPerUnit
    }
}
