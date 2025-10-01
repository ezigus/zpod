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
        // Only attach ModelContainer if we're not in UI test mode or if container was created successfully
        .modifier(ModelContainerModifier(holder: containerHolder))
        #endif
    }
}

#if canImport(LibraryFeature)
/// View modifier that conditionally applies ModelContainer
struct ModelContainerModifier: ViewModifier {
    let holder: ModelContainerHolder
    
    func body(content: Content) -> some View {
        if let container = holder.container {
            content.modelContainer(container)
        } else {
            content
        }
    }
}

/// Holder class to lazily initialize ModelContainer and avoid crashes during struct initialization
@MainActor
class ModelContainerHolder: ObservableObject {
    let container: ModelContainer?
    
    init() {
        let schema = Schema([
            LibraryFeature.Item.self,
        ])
        
        // Detect UI testing environment
        let isUITesting = ProcessInfo.processInfo.environment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] == "1"
        
        // For UI tests, try to create in-memory container but don't crash if it fails
        if isUITesting {
            print("🧪 UI Test mode detected - attempting to create in-memory ModelContainer")
            
            // Try 1: Standard in-memory configuration
            if let container = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            ) {
                print("✅ UI Test: Created in-memory ModelContainer")
                self.container = container
                return
            }
            
            // Try 2: Minimal in-memory with no schema details
            if let container = try? ModelContainer(
                for: LibraryFeature.Item.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ) {
                print("✅ UI Test: Created minimal in-memory ModelContainer")
                self.container = container
                return
            }
            
            // Try 3: Temporary file-based storage
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("UITestDB-\(UUID().uuidString)")
            if let container = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: tempURL)]
            ) {
                print("✅ UI Test: Created temp file ModelContainer")
                self.container = container
                return
            }
            
            // If all fail in UI tests, continue WITHOUT ModelContainer
            print("⚠️ UI Test: Could not create ModelContainer - continuing without SwiftData support")
            self.container = nil
            return
        }
        
        // For production, use persistent storage and crash if it fails
        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer for production: \(error)")
        }
    }
}
#endif
