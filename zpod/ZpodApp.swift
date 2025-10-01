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
    // Use a StateObject to lazily initialize the model container
    @StateObject private var containerHolder = ModelContainerHolder()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if canImport(LibraryFeature)
        .modelContainer(containerHolder.container)
        #endif
    }
}

#if canImport(LibraryFeature)
/// Holder class to lazily initialize ModelContainer
@MainActor
class ModelContainerHolder: ObservableObject {
    let container: ModelContainer
    
    init() {
        // Detect UI testing environment
        let isUITesting = ProcessInfo.processInfo.environment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] == "1"
        
        // For UI tests, use in-memory storage as recommended for CI environments
        if isUITesting {
            do {
                // Use the simple, recommended approach for testing
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                self.container = try ModelContainer(for: LibraryFeature.Item.self, configurations: config)
                print("✅ UI Test: Created in-memory ModelContainer")
            } catch {
                print("❌ UI Test: Failed to create ModelContainer: \(error)")
                // If in-memory fails, something is fundamentally wrong - crash with detailed error
                fatalError("Failed to create in-memory ModelContainer for UI tests: \(error)")
            }
        } else {
            // For production, use persistent storage
            do {
                let schema = Schema([LibraryFeature.Item.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                self.container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer for production: \(error)")
            }
        }
    }
}
#endif
