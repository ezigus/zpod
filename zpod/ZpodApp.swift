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
/// Holder class to lazily initialize ModelContainer and avoid crashes during struct initialization
@MainActor
class ModelContainerHolder: ObservableObject {
    let container: ModelContainer
    
    init() {
        let schema = Schema([
            LibraryFeature.Item.self,
        ])
        
        // Detect UI testing environment
        let isUITesting = ProcessInfo.processInfo.environment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] == "1"
        
        // For UI tests, use in-memory storage with multiple fallbacks
        if isUITesting {
            // Try 1: Standard in-memory configuration
            if let container = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            ) {
                self.container = container
                return
            }
            
            // Try 2: Temporary file-based storage
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("UITestDB-\(UUID().uuidString)")
            if let container = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: tempURL)]
            ) {
                self.container = container
                return
            }
            
            // Try 3: Default configuration
            if let container = try? ModelContainer(for: schema) {
                self.container = container
                return
            }
            
            // If all fail, crash with detailed error
            fatalError("Failed to create ModelContainer for UI tests after trying multiple configurations")
        }
        
        // For production, use persistent storage
        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer for production: \(error)")
        }
    }
}
#endif
