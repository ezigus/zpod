//
//  ZpodApp.swift
//  zpod
//
//  Created by Eric Ziegler on 7/12/25.
//

import SwiftUI
#if canImport(LibraryFeature)
import SwiftData
import LibraryFeature
#endif

@main
struct ZpodApp: App {
    #if canImport(LibraryFeature)
    // Create model container as a static property to ensure single instance
    private static let sharedModelContainer: ModelContainer = {
        // Detect UI testing environment early
        let isUITesting = ProcessInfo.processInfo.environment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] == "1"
        
        if isUITesting {
            print("🧪 UI Test mode - creating in-memory ModelContainer")
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LibraryFeature.Item.self, configurations: config)
                print("✅ UI Test: Successfully created in-memory ModelContainer")
                return container
            } catch {
                print("❌ UI Test: Failed to create ModelContainer: \(error)")
                fatalError("Failed to create in-memory ModelContainer for UI tests: \(error)")
            }
        } else {
            print("📱 Production mode - creating persistent ModelContainer")
            do {
                let schema = Schema([LibraryFeature.Item.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                let container = try ModelContainer(for: schema, configurations: [config])
                print("✅ Production: Successfully created persistent ModelContainer")
                return container
            } catch {
                print("❌ Production: Failed to create ModelContainer: \(error)")
                fatalError("Could not create ModelContainer for production: \(error)")
            }
        }
    }()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if canImport(LibraryFeature)
        .modelContainer(Self.sharedModelContainer)
        #endif
    }
}
