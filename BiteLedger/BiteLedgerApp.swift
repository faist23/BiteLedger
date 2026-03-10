//
//  BiteLedgerApp.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/16/26.
//

import SwiftUI
import SwiftData
import CoreData

@main
struct BiteLedgerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            FoodLog.self,
            ServingSize.self,
            UserPreferences.self,
        ])

        // cloudKitDatabase: .none is required — even though we don't use CloudKit,
        // the capability being present in the entitlements causes SwiftData to attempt
        // CloudKit integration unless explicitly disabled.
        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            print("⚠️ Failed to load existing database (likely schema mismatch): \(error)")
            print("🔄 Deleting old database and creating fresh one...")

            let fileManager = FileManager.default
            if let storeURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("default.store") {
                try? fileManager.removeItem(at: storeURL)
                try? fileManager.removeItem(at: storeURL.appendingPathExtension("shm"))
                try? fileManager.removeItem(at: storeURL.appendingPathExtension("wal"))
                print("✅ Deleted old database files")
            }

            do {
                let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("✅ Created fresh database with new schema")
                return container
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            SafeContentView(modelContainer: sharedModelContainer)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct SafeContentView: View {
    let modelContainer: ModelContainer

    var body: some View {
        ContentView()
    }
}
