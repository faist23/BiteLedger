//
//  FallbackSource.swift
//  BiteLedger
//
//  Created by Craig Faist on 3/14/26.
//

import SwiftData
import Foundation

// MARK: - FallbackSource

/// Persistent record linking a FoodItem to the external data source that
/// provided its micronutrient enrichment (USDA FoodData Central or FatSecret).
///
/// Created during LoseIt enrichment import and stored on `FoodItem.fallbackSourceID`.
/// Enables data provenance display ("Enriched from USDA") and future on-demand
/// re-enrichment without re-running the full import tool.
@Model
final class FallbackSource {

    // MARK: Identity
    var id: UUID = UUID()

    /// "usda" | "fatsecret" | "manual"
    var sourceType: String = ""

    /// External identifier: USDA fdcId (as String) or FatSecret food_id.
    var externalID: String = ""

    /// Display name from the external source (e.g. "PEANUT BUTTER, CREAMY").
    var externalName: String = ""

    /// Match confidence in [0, 1]. Meaningful for USDA matches; 0 for FatSecret/manual.
    var confidence: Double = 1.0

    /// When enrichment was applied.
    var appliedAt: Date = Date()

    // MARK: Init

    init(
        sourceType: String,
        externalID: String,
        externalName: String,
        confidence: Double
    ) {
        self.sourceType = sourceType
        self.externalID = externalID
        self.externalName = externalName
        self.confidence = confidence
        self.appliedAt = Date()
    }

    // MARK: Display

    /// Short label for the metadata row, e.g. "USDA #12345" or "FatSecret".
    var displayLabel: String {
        switch sourceType {
        case "usda":       return "USDA #\(externalID)"
        case "fatsecret":  return "FatSecret"
        case "manual":     return "Manual"
        default:           return sourceType.capitalized
        }
    }

    /// Confidence formatted as a percentage string, or nil when not applicable.
    var confidenceLabel: String? {
        guard sourceType == "usda", confidence > 0 else { return nil }
        return "\(Int(confidence * 100))% match"
    }
}

// MARK: - FallbackSourceInfo

/// Lightweight DTO used to communicate enrichment provenance from
/// `LoseItEnrichmentService.buildFallbackSourceMap()` to
/// `CSVImporter.importLoseItEnriched()` without coupling those two types.
struct FallbackSourceInfo {
    let sourceType: String
    let externalID: String
    let externalName: String
    let confidence: Double
}
