//
//  UserPreferences.swift
//  BiteLedger
//

import Foundation
import SwiftData

@Model
class UserPreferences {
    var dailyCalorieGoal: Double?
    var trackingMetric: TrackingMetric
    var showDailyGoal: Bool
    
    init(dailyCalorieGoal: Double? = nil, trackingMetric: TrackingMetric = .calories, showDailyGoal: Bool = false) {
        self.dailyCalorieGoal = dailyCalorieGoal
        self.trackingMetric = trackingMetric
        self.showDailyGoal = showDailyGoal
    }
}

enum TrackingMetric: String, CaseIterable, Codable {
    case calories = "Calories"
    case protein = "Protein"
    case carbs = "Carbs"
    case fat = "Fat"
    
    var unit: String {
        switch self {
        case .calories:
            return "cal"
        default:
            return "g"
        }
    }
}
