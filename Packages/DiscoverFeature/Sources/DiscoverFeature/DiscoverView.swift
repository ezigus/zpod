#if os(iOS) || os(macOS)
import SwiftUI
import CoreModels
import SearchDomain
import FeedParsing
import SharedUtilities

#if canImport(UIKit)
import UIKit
#endif

private struct DiscoveryOptionsState {
    var isDialogPresented = false
    var isRSSSheetPresented = false
    var isHistorySheetPresented = false

    mutating func presentDialog() {
        isDialogPresented = true
    }

    mutating func cancelDialog() {
        isDialogPresented = false
    }

    mutating func selectRSS() {
        isDialogPresented = false
        isHistorySheetPresented = false
        isRSSSheetPresented = true
    }

    mutating func selectHistory() {
        isDialogPresented = false
        isRSSSheetPresented = false
        isHistorySheetPresented = true
    }

    mutating func dismissRSSSheet() {
        isRSSSheetPresented = false
    }

    mutating func dismissHistorySheet() {
        isHistorySheetPresented = false
    }
}

/// Discovery view with search functionality for finding and subscribing to podcasts
public struct DiscoverView: View {
    @StateObject private var viewModel: SearchViewModel
    @State private var optionsState = DiscoveryOptionsState()
    
    public init(searchService: SearchServicing, podcastManager: PodcastManaging, rssParser: RSSFeedParsing = DefaultRSSFeedParser()) {
        self._viewModel = StateObject(
            wrappedValue: SearchViewModel(
                searchService: searchService,
                podcastManager: podcastManager,
                rssParser: rssParser
            )
        )
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Header
                searchHeaderView
                
                // Content
                if viewModel.isSearching {
                    loadingView
                } else if !viewModel.searchText.isEmpty && viewModel.searchResults.isEmpty {
                    noResultsView
                } else if !viewModel.searchResults.isEmpty {
                    searchResultsView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(NavigationBarAccessibilityModifier(identifier: "Discover"))
            .toolbar {
                ToolbarItem(placement: discoveryToolbarPlacement) {
                    Button {
                        optionsState.presentDialog()
                    } label: {
                        Label("Discovery options", systemImage: "plus.circle")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityIdentifier("discovery-options-menu")
                    .accessibilityHint("Opens menu with podcast discovery options")
                    .confirmationDialog(
                        "Discovery Options",
                        isPresented: Binding(
                            get: { optionsState.isDialogPresented },
                            set: { presented in
                                if presented {
                                    optionsState.isDialogPresented = true
                                } else {
                                    optionsState.cancelDialog()
                                }
                            }
                        )
                    ) {
                        Button("Add RSS Feed") {
                            optionsState.selectRSS()
                        }
                        .accessibilityIdentifier("discovery-options-menu.add-rss")
                        Button("Search History") {
                            optionsState.selectHistory()
                        }
                        .accessibilityIdentifier("discovery-options-menu.search-history")
                        .disabled(viewModel.searchHistory.isEmpty)
                        Button("Clear History", role: .destructive) {
                            viewModel.clearSearchHistory()
                            optionsState.cancelDialog()
                        }
                        .disabled(viewModel.searchHistory.isEmpty)
                        Button("Cancel", role: .cancel) {
                            optionsState.cancelDialog()
                        }
                    }
                }
            }
            .sheet(isPresented: rssSheetBinding) {
                rssAddView
            }
            .sheet(isPresented: historySheetBinding) {
                searchHistoryView
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private var rssSheetBinding: Binding<Bool> {
        Binding(
            get: { optionsState.isRSSSheetPresented },
            set: { isPresented in
                if isPresented {
                    optionsState.isRSSSheetPresented = true
                } else {
                    optionsState.dismissRSSSheet()
                }
            }
        )
    }

    private var historySheetBinding: Binding<Bool> {
        Binding(
            get: { optionsState.isHistorySheetPresented },
            set: { isPresented in
                if isPresented {
                    optionsState.isHistorySheetPresented = true
                } else {
                    optionsState.dismissHistorySheet()
                }
            }
        )
    }

    private var discoveryToolbarPlacement: ToolbarItemPlacement {
#if os(iOS)
        .navigationBarTrailing
#else
        .primaryAction
#endif
    }

    private var rssCancelToolbarPlacement: ToolbarItemPlacement {
#if os(iOS)
        .navigationBarTrailing
#else
        .cancellationAction
#endif
    }

    private var historyDoneToolbarPlacement: ToolbarItemPlacement {
#if os(iOS)
        .navigationBarTrailing
#else
        .primaryAction
#endif
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var searchHeaderView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search podcasts, episodes...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await viewModel.search()
                        }
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: viewModel.clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.platformSystemGray6)
            .cornerRadius(12)
            
            // Filter options
            if !viewModel.searchText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach([SearchFilter.all, .podcastsOnly, .episodesOnly], id: \.self) { filter in
                            filterButton(for: filter)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color.platformSystemBackground)
    }
    
    private func filterButton(for filter: SearchFilter) -> some View {
        Button(action: {
            viewModel.currentFilter = filter
            Task {
                await viewModel.search()
            }
        }) {
            Text(filterLabel(for: filter))
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    viewModel.currentFilter == filter ? 
                    Color.accentColor : Color.platformSystemGray5
                )
                .foregroundColor(
                    viewModel.currentFilter == filter ? 
                    .white : .primary
                )
                .cornerRadius(16)
        }
        .accessibilityLabel(filterLabel(for: filter))
    }
    
    private func filterLabel(for filter: SearchFilter) -> String {
        switch filter {
        case .all: return "All"
        case .podcastsOnly: return "Podcasts"
        case .episodesOnly: return "Episodes"
        case .notesOnly: return "Notes"
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.headline)
            
            Text("Try adjusting your search terms or filters")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("Discover Podcasts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Search for podcasts by name, category, or episode title")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: { optionsState.selectRSS() }) {
                    Label("Add RSS Feed", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("discover-empty-add-rss")
                
                if !viewModel.searchHistory.isEmpty {
                    Button(action: { optionsState.selectHistory() }) {
                        Label("Recent Searches", systemImage: "clock")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var searchResultsView: some View {
        List(viewModel.searchResults.indices, id: \.self) { index in
            SearchResultView(
                searchResult: viewModel.searchResults[index],
                onSubscribe: viewModel.subscribe
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
    }
    
    private var rssAddView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RSS Feed URL")
                        .font(.headline)
                    
                    TextField("https://example.com/podcast.xml", text: $viewModel.rssURL)
                        .textFieldStyle(.roundedBorder)
#if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                        .accessibilityIdentifier("rss-url-field")
                    
                    Text("Enter the direct RSS feed URL of the podcast you want to add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    Task {
                        await viewModel.addPodcastByRSSURL()
                        if viewModel.errorMessage == nil {
                            optionsState.dismissRSSSheet()
                        }
                    }
                }) {
                    if viewModel.isAddingRSSFeed {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Adding...")
                        }
                    } else {
                        Text("Add Podcast")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.rssURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAddingRSSFeed)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add RSS Feed")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: rssCancelToolbarPlacement) {
                    Button("Cancel") {
                        optionsState.dismissRSSSheet()
                    }
                }
            }
        }
    }
    
    private var searchHistoryView: some View {
        NavigationStack {
            List {
                ForEach(viewModel.searchHistory, id: \.self) { query in
                    Button(action: {
                        viewModel.useSearchFromHistory(query)
                        optionsState.dismissHistorySheet()
                    }) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text(query)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    viewModel.searchHistory.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("Search History")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: historyDoneToolbarPlacement) {
                    Button("Done") {
                        optionsState.dismissHistorySheet()
                    }
                }
            }
        }
    }
}

// MARK: - Navigation Bar Accessibility Helper

#if canImport(UIKit)
/// Modifier to set accessibility identifier on SwiftUI navigation bar
private struct NavigationBarAccessibilityModifier: ViewModifier {
  let identifier: String

  func body(content: Content) -> some View {
    content
      .background(
        NavigationBarAccessibilityHelper(identifier: identifier)
          .frame(height: 0)
      )
  }
}

/// Helper to tag the native navigation bar with accessibility identifier
private struct NavigationBarAccessibilityHelper: UIViewRepresentable {
  let identifier: String

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      // Find the navigation bar and set its accessibility identifier
      if let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first?.windows.first,
        let navBar = findNavigationBar(in: window) {
        navBar.accessibilityIdentifier = identifier
      }
    }
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}

  private func findNavigationBar(in view: UIView) -> UINavigationBar? {
    if let navBar = view as? UINavigationBar {
      return navBar
    }
    for subview in view.subviews {
      if let navBar = findNavigationBar(in: subview) {
        return navBar
      }
    }
    return nil
  }
}
#else
/// No-op modifier when UIKit is not available
private struct NavigationBarAccessibilityModifier: ViewModifier {
  let identifier: String

  func body(content: Content) -> some View {
    content
  }
}
#endif

#else
import SwiftUI
import CoreModels
import SearchDomain
import FeedParsing

public struct DiscoverView: View {
    public init(searchService: SearchServicing, podcastManager: PodcastManaging, rssParser: RSSFeedParsing = DefaultRSSFeedParser()) {}

    public var body: some View {
        Text("Discover view is available on iOS only.")
    }
}
#endif

#if DEBUG
struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock services for preview
        let mockSearchService = MockSearchService()
        let mockPodcastManager = MockPodcastManager()
        
        DiscoverView(
            searchService: mockSearchService,
            podcastManager: mockPodcastManager,
            rssParser: MockRSSParser()
        )
    }
}

// Mock implementations for previews
@MainActor
private class MockSearchService: SearchServicing {
    func search(query: String, filter: SearchFilter?) async -> [SearchResult] {
        // Mock search results
        return [
            .podcast(
                Podcast(
                    id: "mock-podcast",
                    title: "Swift Talk",
                    author: "objc.io",
                    description: "A weekly video series on Swift programming.",
                    feedURL: URL(string: "https://example.com/feed")!
                ),
                relevanceScore: 0.95
            )
        ]
    }
    
    func rebuildIndex() async {
        // Mock implementation
    }
}

private final class MockRSSParser: RSSFeedParsing, @unchecked Sendable {
    func parseFeed(from url: URL) async throws -> Podcast {
        return Podcast(
            id: "mock-podcast",
            title: "Mock Podcast",
            feedURL: url
        )
    }
}

private final class MockPodcastManager: PodcastManaging, @unchecked Sendable {
    func all() -> [Podcast] { [] }
    func find(id: String) -> Podcast? { nil }
    func add(_ podcast: Podcast) { }
    func update(_ podcast: Podcast) { }
    func remove(id: String) { }
    func findByFolder(folderId: String) -> [Podcast] { [] }
    func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] { [] }
    func findByTag(tagId: String) -> [Podcast] { [] }
    func findUnorganized() -> [Podcast] { [] }
}
#endif
