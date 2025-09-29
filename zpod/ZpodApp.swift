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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LibraryFeature.Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch let error as NSError {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if canImport(LibraryFeature)
        .modelContainer(sharedModelContainer)
        #endif
    }
}
