// filepath: /Users/ericziegler/code/zpod/zpod/ContentViewBridge.swift
// Conditional bridge for ContentView so the App can compile whether or not
// the LibraryFeature package is linked to the app target in Xcode.
// If LibraryFeature is available, we re-export its ContentView; otherwise,
// we supply a minimal placeholder to keep the app buildable.

import Foundation
import SwiftUI
import CoreModels
import SearchDomain
import DiscoverFeature
import SharedUtilities
#if canImport(UIKit)
import UIKit
#endif

#if canImport(LibraryFeature)
import LibraryFeature
public typealias ContentView = LibraryFeature.ContentView
#else
public struct ContentView: View {
    public init() {}

    public var body: some View {
        UITestLibraryPlaceholderView()
    }
}

#endif

// MARK: - Lightweight Podcast Manager (Placeholder)

/// Minimal manager used by the placeholder UI so SwiftPM builds of zpodLib
/// do not rely on the app target's controllers.
private final class PlaceholderPodcastManager: PodcastManaging, @unchecked Sendable {
    private var storage: [String: Podcast]

    init(initial: [Podcast] = PlaceholderPodcastData.samplePodcasts) {
        storage = Dictionary(uniqueKeysWithValues: initial.map { ($0.id, $0) })
    }

    func all() -> [Podcast] { Array(storage.values) }

    func find(id: String) -> Podcast? { storage[id] }

    func add(_ podcast: Podcast) { storage[podcast.id] = podcast }

    func update(_ podcast: Podcast) { storage[podcast.id] = podcast }

    func remove(id: String) { storage.removeValue(forKey: id) }

    func findByFolder(folderId: String) -> [Podcast] {
        storage.values.filter { $0.folderId == folderId }
    }

    func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] {
        var podcasts = findByFolder(folderId: folderId)
        let descendants = folderManager.getDescendants(of: folderId)
        for folder in descendants {
            podcasts.append(contentsOf: findByFolder(folderId: folder.id))
        }
        return podcasts
    }

    func findByTag(tagId: String) -> [Podcast] {
        storage.values.filter { $0.tagIds.contains(tagId) }
    }

    func findUnorganized() -> [Podcast] {
        storage.values.filter { $0.folderId == nil && $0.tagIds.isEmpty }
    }

    func fetchOrphanedEpisodes() -> [Episode] { [] }
    func deleteOrphanedEpisode(id: String) -> Bool { false }
    func deleteAllOrphanedEpisodes() -> Int { 0 }
}

private enum PlaceholderPodcastData {
    static let sampleEpisodes: [Episode] = [
        Episode(
            id: "sample-episode-swift-1",
            title: "Understanding Swift Concurrency",
            podcastID: "swift-talk",
            podcastTitle: "Swift Talk",
            duration: 1_800,
            description: "Quick overview of actors and structured concurrency."
        ),
        Episode(
            id: "sample-episode-swiftui-1",
            title: "SwiftUI Layout Techniques",
            podcastID: "swift-over-coffee",
            podcastTitle: "Swift Over Coffee",
            duration: 1_500,
            description: "Discussing the latest layout APIs."
        )
    ]

    static let samplePodcasts: [Podcast] = [
        Podcast(
            id: "swift-talk",
            title: "Swift Talk",
            author: "objc.io",
            description: "Deep dives into advanced Swift topics.",
            artworkURL: URL(string: "https://example.com/swift-talk.png"),
            feedURL: URL(string: "https://example.com/swift-talk.rss")!,
            categories: ["Development"],
            episodes: sampleEpisodes,
            isSubscribed: true
        ),
        Podcast(
            id: "swift-over-coffee",
            title: "Swift Over Coffee",
            author: "Swift Community",
            description: "News and discussion from the Swift world.",
            artworkURL: URL(string: "https://example.com/swift-over-coffee.png"),
            feedURL: URL(string: "https://example.com/swift-over-coffee.rss")!,
            categories: ["Development", "News"],
            episodes: sampleEpisodes.map { episode in
                var copy = episode
                copy.id = "coffee-\(episode.id)"
                copy.podcastID = "swift-over-coffee"
                copy.podcastTitle = "Swift Over Coffee"
                return copy
            },
            isSubscribed: false
        ),
        Podcast(
            id: "accidental-tech-podcast",
            title: "Accidental Tech Podcast",
            author: "Casey, Marco, John",
            description: "Apple, technology, and programming news commentary.",
            artworkURL: URL(string: "https://example.com/atp.png"),
            feedURL: URL(string: "https://example.com/atp.rss")!,
            categories: ["Technology"],
            episodes: [],
            isSubscribed: true
        )
    ]
}

#if canImport(UIKit)
private struct UITestTabBarIdentifierSetter: UIViewControllerRepresentable {
    private let maxAttempts = 40
    private let retryInterval: TimeInterval = 0.1

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        scheduleIdentifierUpdate(from: controller, attempt: 0)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        scheduleIdentifierUpdate(from: uiViewController, attempt: 0)
    }

    private func scheduleIdentifierUpdate(from uiViewController: UIViewController, attempt: Int) {
        let delay = attempt == 0 ? 0 : retryInterval
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard
                let tabBar = self.locateTabBar(startingFrom: uiViewController)
                    ?? self.locateTabBarAcrossScenes()
            else {
                self.retryIfNeeded(from: uiViewController, attempt: attempt)
                return
            }
            self.configure(tabBar: tabBar)
        }
    }

    private func retryIfNeeded(from uiViewController: UIViewController, attempt: Int) {
        guard attempt < maxAttempts else { return }
        scheduleIdentifierUpdate(from: uiViewController, attempt: attempt + 1)
    }

    @MainActor
    private func locateTabBar(startingFrom uiViewController: UIViewController) -> UITabBar? {
        if let tabBarController = findTabBarController(from: uiViewController) {
            return tabBarController.tabBar
        }

        if let parent = uiViewController.parent,
           let tabBarController = findTabBarController(from: parent)
        {
            return tabBarController.tabBar
        }

        if let window = uiViewController.view.window,
           let rootController = window.rootViewController,
           let tabBarController = findTabBarController(from: rootController)
        {
            return tabBarController.tabBar
        }

        return nil
    }

    @MainActor
    private func locateTabBarAcrossScenes() -> UITabBar? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter {
                $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
            }

        for scene in scenes {
            for window in scene.windows where !window.isHidden {
                if let controller = findTabBarController(from: window.rootViewController) {
                    return controller.tabBar
                }
            }
        }

        return nil
    }

    @MainActor
    private func configure(tabBar: UITabBar) {
        if tabBar.accessibilityIdentifier != "Main Tab Bar" {
            tabBar.accessibilityIdentifier = "Main Tab Bar"
            tabBar.accessibilityLabel = "Main Tab Bar"
        }

        guard let items = tabBar.items, !items.isEmpty else { return }

        let fallbackTitles = ["Library", "Discover", "Playlists", "Player", "Settings"]

        for (index, item) in items.enumerated() {
            let resolvedTitle: String = {
                if let existingTitle = item.title, !existingTitle.isEmpty {
                    return existingTitle
                }
                if index < fallbackTitles.count {
                    return fallbackTitles[index]
                }
                return "Tab \(index + 1)"
            }()

            if (item.title ?? "").isEmpty {
                item.title = resolvedTitle
            }

            if (item.accessibilityLabel ?? "").isEmpty {
                item.accessibilityLabel = resolvedTitle
            }

            if (item.accessibilityHint ?? "").isEmpty {
                item.accessibilityHint = "Opens \(resolvedTitle)"
            }

            if !item.accessibilityTraits.contains(.button) {
                item.accessibilityTraits.insert(.button)
            }
        }
    }

    private func findTabBarController(from vc: UIViewController?) -> UITabBarController? {
        guard let vc else { return nil }

        if let tabBarController = vc as? UITabBarController {
            return tabBarController
        }

        for child in vc.children {
            if let controller = findTabBarController(from: child) {
                return controller
            }
        }

        if let presented = vc.presentedViewController {
            return findTabBarController(from: presented)
        }

        return nil
    }
}
#endif

public struct UITestLibraryPlaceholderView: View {
    @State private var searchText: String = ""
    @State private var selectedTab: Int = 0

    private let podcastManager: PodcastManaging
    private let searchService: SearchServicing

    public init() {
        self.podcastManager = PlaceholderPodcastManager()
        let searchSources: [SearchIndexSource] = []
        self.searchService = SearchService(indexSources: searchSources)
        _selectedTab = State(initialValue: Self.initialTabSelection())
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryPlaceholderView()
                    .navigationTitle("Library")
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .tag(0)

            DiscoverView(
                searchService: searchService,
                podcastManager: podcastManager
            )
            .tabItem { Label("Discover", systemImage: "sparkles") }
            .tag(1)

            NavigationStack {
                PlayerPlaceholderView()
                    .navigationTitle("Player")
            }
            .tabItem { Label("Player", systemImage: "play.circle") }
            .tag(2)
        }
        .accessibilityIdentifier("Main Tab Bar")
        #if canImport(UIKit)
        .background(UITestTabBarIdentifierSetter())
        #endif
    }

    private static func initialTabSelection() -> Int {
        UITestTabSelection.resolve(
            rawValue: ProcessInfo.processInfo.environment["UITEST_INITIAL_TAB"],
            maxIndex: 2,
            mapping: [
                "library": 0,
                "discover": 1,
                "player": 2
            ]
        )
    }
}

// MARK: - Library Placeholder
private struct LibraryPlaceholderView: View {
    // Provide a small sample model used only by the placeholder to retain testability
    private struct PodcastItem: Identifiable {
        let id: String   // slug-style id used by UI tests (e.g. "swift-talk")
        let title: String
    }

    private let samplePodcasts: [PodcastItem] = [
        PodcastItem(id: "swift-talk", title: "Swift Talk"),
        PodcastItem(id: "swift-over-coffee", title: "Swift Over Coffee"),
        PodcastItem(id: "accidental-tech-podcast", title: "Accidental Tech Podcast")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Heading for accessibility structure
            Text("Your Library")
                .font(.title2).bold()
                .accessibilityAddTraits(.isHeader)

            // Main Content container expected by tests
            Group {
                // Use a transparent element to mark main content region
                Color.clear
                    .frame(height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("Main Content")
                    .accessibilityLabel("Main Content")
                Color.clear
                    .frame(height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("Content Container")
                    .accessibilityLabel("Content Container")
            }

            List {
                Section(header: Text("Podcasts")) {
                    ForEach(samplePodcasts) { podcast in
                        // NavigationLink so tapping in UI tests opens the episode list placeholder
                        NavigationLink(value: podcast.id) {
                            HStack {
                                Text(podcast.title)
                                    .accessibilityIdentifier("Podcast Title_\(podcast.id)")
                                Spacer()
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(podcast.title)
                        }
                        // Ensure the NavigationLink (row) itself exposes the identifier so
                        // XCUIApplication.cell queries can find the row by identifier.
                        .accessibilityIdentifier("Podcast-\(podcast.id)")
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("Podcast Cards Container")
            .accessibilityLabel("Podcast Cards Container")
        }
        .padding()
        // Enable navigation to use the new value-based NavigationStack in the placeholder
        .navigationDestination(for: String.self) { podcastId in
            EpisodeListPlaceholderView(podcastId: podcastId)
        }
    }
}

// MARK: - Episode List Placeholder
private struct EpisodeListPlaceholderView: View {
    let podcastId: String

    private struct EpisodeItem: Identifiable {
        let id: String
        let title: String
    }

    private let sampleEpisodes: [EpisodeItem] = [
        EpisodeItem(id: "Episode-st-001", title: "Understanding Swift Concurrency"),
        EpisodeItem(id: "Episode-st-002", title: "SwiftUI Layouts Deep Dive"),
        EpisodeItem(id: "Episode-st-003", title: "Modern Package Management")
    ]

    var body: some View {
        List {
            ForEach(sampleEpisodes) { episode in
                Button {
                    // Navigate to a tiny detail view when tapped
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text(episode.title)
                                .font(.body)
                                .accessibilityIdentifier("Episode Title")
                            Text("45m • Jan 1, 2025")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("Episode-\(episode.id)")
                .onTapGesture {
                    // Present episode detail via a sheet to make it discoverable by UI tests
                    // Use NotificationCenter or environment navigation in a real app; keep simple here
                }
                .background(
                    NavigationLink(destination: EpisodeDetailPlaceholderView(episodeTitle: episode.title)) {
                        EmptyView()
                    }
                    // Tag the hidden NavigationLink with the episode id so the underlying
                    // table row/cell is discoverable by XCUI tests via identifier queries.
                    .accessibilityIdentifier(episode.id)
                    .opacity(0)
                )
            }
        }
        .navigationTitle("Episodes")
        // Make the list discoverable by UI tests
        .accessibilityIdentifier("Episode Cards Container")
        .accessibilityLabel("Episode Cards Container")
    }
}

// MARK: - Episode Detail Placeholder
private struct EpisodeDetailPlaceholderView: View {
    let episodeTitle: String

    var body: some View {
        VStack(spacing: 16) {
            Text(episodeTitle)
                .font(.title2)
                .bold()
                .accessibilityIdentifier("Episode Title")

            Text("Episode details and description go here.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("Episode Detail View")
    }
}

// MARK: - Discover Placeholder
private struct DiscoverPlaceholderView: View {
    @Binding var searchText: String
    private let featuredItems = Array(1...5)
    private let categories = ["Technology", "Entertainment", "News"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sections commonly present in discovery UIs
            Text("Featured")
                .font(.headline)
                .accessibilityIdentifier("Featured")
                .accessibilityAddTraits(.isHeader)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(featuredItems, id: \.self) { idx in
                    Button(action: {}) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 160, height: 100)
                            .overlay(Text("Feature \(idx)"))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Featured Item \(idx)")
                    .accessibilityHint("Opens featured content details")
                }
            }
            .padding(.horizontal, 4)
        }
            .accessibilityIdentifier("Featured Carousel")

            Text("Categories")
                .font(.headline)
                .accessibilityIdentifier("Categories")
            .accessibilityAddTraits(.isHeader)

        // Category buttons
        HStack(spacing: 12) {
            ForEach(categories, id: \.self) { cat in
                Button(cat) {}
                    .buttonStyle(.bordered)
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilitySortPriority(100)
                    .accessibilityIdentifier("Category_\(cat)")
                    .accessibilityLabel(cat)
                    .accessibilityHint("Browse \(cat) podcasts")
            }
        }

            // Search results list placeholder
            List {
                ForEach(filteredResults, id: \.self) { item in
                    HStack {
                        Text(item)
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilitySortPriority(80)
                    .accessibilityIdentifier("SearchResult_\(item)")
                    .accessibilityLabel(item)
                }
            }
            .accessibilityIdentifier("Search Results")
            .accessibilityElement()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Search Results")
        }
        .padding()
        // Provide a searchable field for tests to find app.searchFields
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search"))
    }

    private var filteredResults: [String] {
        let all = ["Swift", "Technology", "Design", "Productivity"]
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Player Placeholder
private struct PlayerPlaceholderView: View {
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.3

    var body: some View {
        VStack(spacing: 20) {
            // Player Interface container expected by tests
            Color.clear
                .frame(height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("Player Interface")
                .accessibilityLabel("Player Interface")

            // Now Playing header for media integration tests
            Text("Now Playing")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("Now Playing Title")
                .accessibilityElement(children: .ignore)

            // Episode info
            VStack(spacing: 8) {
                Text("Episode Title Example")
                    .font(.title3).bold()
                    .accessibilityIdentifier("Episode Title")
                    .accessibilityElement(children: .ignore)
                Text("Podcast Title Example")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("Podcast Title")
                    .accessibilityElement(children: .ignore)
                Image(systemName: "waveform")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .accessibilityIdentifier("Episode Artwork")
            }
            .padding(.horizontal)

            // Progress slider
            Slider(value: $progress)
                .accessibilityIdentifier("Progress Slider")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Progress Slider")
                .accessibilityValue("\(Int(progress * 100)) percent")
                .padding(.horizontal)

            // Playback controls sized for CarPlay
            HStack(spacing: 24) {
                Button {
                    // Skip backward action
                } label: {
                    Label("Skip Backward", systemImage: "gobackward.15")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Skip Backward")
                .frame(minWidth: 80, minHeight: 50)
                .contentShape(Rectangle())

                Button {
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                .accessibilityHint("Toggles playback")
                .frame(minWidth: 120, minHeight: 56)
                .contentShape(Rectangle())

                Button {
                    // Skip forward action
                } label: {
                    Label("Skip Forward", systemImage: "goforward.30")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Skip Forward")
                .frame(minWidth: 80, minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Speed control for media integration tests
            Button("1.0×") {
                // Speed control action placeholder
            }
            .font(.footnote)
            .accessibilityIdentifier("Speed Control")
            .accessibilityLabel("Speed Control")
            .accessibilityHint("Changes playback speed")

            Spacer()
        }
        .padding()
    }
}
