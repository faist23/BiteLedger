//
//  BiteLedgerApp.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData

@main
struct BiteLedgerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [FoodItem.self, FoodLog.self, UserPreferences.self])
    }
}
