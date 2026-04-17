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
        UITestLibraryPlaceholderView(seedPodcasts: Self.uiTestSeeds())
    }

    private static func uiTestSeeds() -> [Podcast] {
        guard ProcessInfo.processInfo.environment["UITEST_SEED_PODCASTS"] == "1" else { return [] }
        return [
            Podcast(
                id: "swift-talk",
                title: "Swift Talk",
                author: "objc.io",
                description: "Deep dives into advanced Swift topics.",
                feedURL: URL(string: "https://example.com/swift-talk.rss")!,
                isSubscribed: true
            )
        ]
    }
}

#endif

// MARK: - Lightweight Podcast Manager (Placeholder)

/// Minimal manager used by the placeholder UI so SwiftPM builds of zpodLib
/// do not rely on the app target's controllers.
private final class PlaceholderPodcastManager: PodcastManaging, @unchecked Sendable {
    private var storage: [String: Podcast]

    /// Initialize with an empty store; callers must explicitly seed with podcasts via `initial:`.
    /// Hardcoded sample data was removed per issue #32.1; use TestSupport PodcastFixtures
    /// in test code and the UITEST_SEED_PODCASTS environment flag for UI test seeding.
    init(initial: [Podcast] = []) {
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


#if canImport(UIKit)
/// Sets accessibility identifiers on the UIKit tab bar once, from `viewDidAppear`.
///
/// Using `viewDidAppear` instead of `DispatchQueue.main.asyncAfter` is critical for
/// XCUITest quiescence: `asyncAfter` keeps posting work items on the main run loop
/// (especially when called from `updateUIViewController` on every SwiftUI re-render),
/// preventing XCUITest's idle detector from ever seeing the app as idle.
private struct UITestTabBarIdentifierSetter: UIViewControllerRepresentable {

    final class Coordinator {
        var isConfigured = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> TabBarConfigViewController {
        let controller = TabBarConfigViewController()
        controller.onViewDidAppear = { [coordinator = context.coordinator] in
            guard !coordinator.isConfigured else { return }
            coordinator.isConfigured = true
            if let tabBar = controller.locateTabBar() {
                configure(tabBar: tabBar)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: TabBarConfigViewController, context: Context) {
        // Intentionally empty — configuration is one-shot from viewDidAppear.
        // Doing work here would re-run on every SwiftUI re-render.
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

            if (item.title ?? "").isEmpty { item.title = resolvedTitle }
            if (item.accessibilityLabel ?? "").isEmpty { item.accessibilityLabel = resolvedTitle }
            if (item.accessibilityIdentifier ?? "").isEmpty { item.accessibilityIdentifier = resolvedTitle }
            if (item.accessibilityHint ?? "").isEmpty { item.accessibilityHint = "Opens \(resolvedTitle)" }
            if !item.accessibilityTraits.contains(.button) { item.accessibilityTraits.insert(.button) }
        }
    }
}

/// UIViewController subclass used by `UITestTabBarIdentifierSetter` to obtain a
/// synchronous `viewDidAppear` callback without scheduling async main-queue work.
final class TabBarConfigViewController: UIViewController {
    var onViewDidAppear: (() -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onViewDidAppear?()
        onViewDidAppear = nil  // fire once, then release
    }

    func locateTabBar() -> UITabBar? {
        if let tbc = findTabBarController(from: self) { return tbc.tabBar }
        if let parent, let tbc = findTabBarController(from: parent) { return tbc.tabBar }
        if let root = view.window?.rootViewController,
           let tbc = findTabBarController(from: root) { return tbc.tabBar }

        // Fall back to scanning all foreground scenes
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .flatMap { $0.windows }
            .filter { !$0.isHidden }
            .compactMap { findTabBarController(from: $0.rootViewController)?.tabBar }
            .first
    }

    private func findTabBarController(from vc: UIViewController?) -> UITabBarController? {
        guard let vc else { return nil }
        if let tbc = vc as? UITabBarController { return tbc }
        for child in vc.children {
            if let tbc = findTabBarController(from: child) { return tbc }
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

    public init(seedPodcasts: [Podcast] = []) {
        self.podcastManager = PlaceholderPodcastManager(initial: seedPodcasts)
        let searchSources: [SearchIndexSource] = []
        self.searchService = SearchService(indexSources: searchSources)
        _selectedTab = State(initialValue: Self.initialTabSelection())
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryPlaceholderView(podcastManager: podcastManager)
                    .navigationTitle("Library")
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .tag(0)

            DiscoverView(
                searchService: searchService,
                podcastManager: podcastManager,
                directoryService: DirectoryServiceFactory.makeDefault(
                    podcastIndexAPIKey: Bundle.main.infoDictionary?["PODCAST_INDEX_API_KEY"] as? String,
                    podcastIndexAPISecret: Bundle.main.infoDictionary?["PODCAST_INDEX_API_SECRET"] as? String
                )
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
    let podcastManager: PodcastManaging

    var body: some View {
        let podcasts = podcastManager.all()
        VStack(spacing: 0) {
            // Heading for accessibility structure
            Text("Your Library")
                .font(.title2).bold()
                .accessibilityAddTraits(.isHeader)
                .padding(.top)

            // Accessibility markers preserved so existing UI test navigation still works
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

            if podcasts.isEmpty {
                Spacer()
                Text("No podcasts yet.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(podcasts, id: \.id) { podcast in
                    NavigationLink(destination: EpisodeListPlaceholderView(podcastTitle: podcast.title)) {
                        Text(podcast.title)
                    }
                    .accessibilityIdentifier("Podcast-\(podcast.id)")
                }
            }
        }
        .accessibilityIdentifier("Podcast Cards Container")
    }
}

// MARK: - Episode List Placeholder
private struct EpisodeListPlaceholderView: View {
    let podcastTitle: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No episodes yet.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .navigationTitle(podcastTitle)
        .accessibilityIdentifier("Episode Cards Container")
        .accessibilityLabel("Episode Cards Container")
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
