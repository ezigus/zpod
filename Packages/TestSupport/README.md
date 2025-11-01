# TestSupport Package

This package provides reusable test helpers, mocks, and builders for integration and unit tests across the zPod project.

## Overview

The TestSupport package consolidates common test utilities to eliminate duplication and provide consistent test infrastructure. It includes:

- **Mock Implementations**: Test doubles for core services (episode state, playlists)
- **In-Memory Managers**: Lightweight managers for podcasts and folders
- **Mock Data Factories**: Factory methods for creating test data
- **Test Extensions**: Convenience methods for common test operations

## Components

### Mock Implementations

#### MockEpisodeStateManager
Thread-safe mock for `EpisodeStateManager` protocol. Maintains episode state in actor-isolated storage.

```swift
let episodeStateManager = MockEpisodeStateManager()
await episodeStateManager.setPlayedStatus(episode, isPlayed: true)
let state = await episodeStateManager.getEpisodeState(episode)
```

#### PlaylistManager
`@MainActor`-bound mock playlist manager for testing playlist workflows.

```swift
let playlistManager = PlaylistManager()
await playlistManager.createPlaylist(myPlaylist)
await playlistManager.createSmartPlaylist(smartPlaylist)
```

#### PlaylistEngine
Stateless engine for evaluating smart playlists and generating playback queues.

```swift
let engine = PlaylistEngine()
let episodes = await engine.evaluateSmartPlaylist(smartPlaylist, episodes: allEpisodes, downloadStatuses: statuses)
let queue = await engine.generatePlaybackQueue(from: playlist, episodes: allEpisodes, shuffle: true)
```

#### PlaylistTestBuilder
Simplifies playlist and smart playlist creation for tests.

```swift
let builder = await PlaylistTestBuilder()
    .withPlaylistManager(playlistManager)
    .addManualPlaylist(name: "Favorites", episodeIds: ["ep1", "ep2", "ep3"])
    .addUnplayedSmartPlaylist(maxEpisodes: 20)
    .addDownloadedSmartPlaylist(maxEpisodes: 50)
```

### In-Memory Managers

#### InMemoryPodcastManager
Lightweight, in-memory podcast storage for tests. Supports organization by folders and tags.

```swift
let manager = InMemoryPodcastManager()
manager.add(podcast)
manager.update(podcast)
let podcasts = manager.findByFolder(folderId: "tech")
```

#### InMemoryFolderManager
In-memory folder hierarchy management with validation for parent-child relationships.

```swift
let manager = InMemoryFolderManager()
try manager.add(folder)
let children = manager.getChildren(of: folderId)
let descendants = manager.getDescendants(of: folderId)
```

### Mock Data Factories

The `Mocks` module provides factory methods for creating test data:

```swift
// Create sample podcasts
let podcast = MockPodcast.createSample(id: "pod1", title: "My Podcast")
let podcastWithFolder = MockPodcast.createWithFolder(id: "pod2", title: "Tech Podcast", folderId: "tech")

// Create sample episodes
let episode = MockEpisode.createSample(id: "ep1", title: "Episode 1", podcastID: "pod1")
let episodeWithDuration = MockEpisode.createWithDuration(id: "ep2", title: "Long Episode", duration: 3600)

// Create folders
let folder = MockFolder.createSample(id: "folder1", name: "My Folder")
let childFolder = MockFolder.createChild(id: "child1", name: "Child Folder", parentId: "folder1")

// Create playlists
let playlist = MockPlaylist.createManual(id: "playlist1", name: "My Playlist", episodeIds: ["ep1", "ep2"])
let smartPlaylist = MockPlaylist.createSmart(id: "smart1", name: "Smart Playlist")
```

### Test Extensions

Extensions add test-specific convenience methods:

```swift
// Podcast extensions
let subscribedPodcast = podcast.withSubscriptionStatus(true)

// InMemoryPodcastManager extensions
let subscribed = manager.getSubscribedPodcasts()
let allInFolder = manager.findByFolderRecursive(folderId: "tech", folderManager: folderManager)
```

## Integration Test Support

For integration tests that require SearchDomain or DiscoverFeature dependencies, additional test helpers are provided in the `IntegrationTests` directory:

- **MockRSSParser**: Mock for RSS feed parsing (requires DiscoverFeature)
- **WorkflowTestBuilder**: Builder for setting up complex workflow test scenarios (requires SearchDomain)
- **SearchTestBuilder**: Builder for search operation helpers (requires SearchDomain)

These helpers cannot be included in TestSupport due to circular dependency constraints.

## Usage in Tests

### Unit Tests

Use mocks and factories for focused unit tests:

```swift
func testEpisodeState() async throws {
    let episodeStateManager = MockEpisodeStateManager()
    let episode = MockEpisode.createSample(id: "ep1", title: "Test Episode")
    
    await episodeStateManager.setPlayedStatus(episode, isPlayed: true)
    let state = await episodeStateManager.getEpisodeState(episode)
    
    XCTAssertTrue(state.isPlayed)
}
```

### Integration Tests

Use builders and in-memory managers for integration tests:

```swift
final class MyIntegrationTests: XCTestCase {
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    private var playlistManager: PlaylistManager!
    
    override func setUp() {
        super.setUp()
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()
        
        let setupExpectation = expectation(description: "Setup")
        Task { @MainActor in
            playlistManager = PlaylistManager()
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 5.0)
    }
    
    func testWorkflow() async throws {
        // Setup test data
        let podcast = MockPodcast.createWithFolder(id: "pod1", title: "Tech Podcast", folderId: "tech")
        podcastManager.add(podcast)
        
        // Use PlaylistTestBuilder
        _ = await PlaylistTestBuilder()
            .withPlaylistManager(playlistManager)
            .addManualPlaylist(name: "Favorites", episodeIds: ["ep1"])
        
        // Run assertions
        XCTAssertEqual(playlistManager.playlists.count, 1)
    }
}
```

## Actor Safety

All test helpers follow Swift 6 concurrency guidelines:

- Mock implementations are marked `@unchecked Sendable` with appropriate actor isolation
- Builders operate on `@MainActor` when required (e.g., `PlaylistTestBuilder`)
- Stateless helpers like `PlaylistEngine` are safe to use across concurrency boundaries

## Adding New Helpers

When adding new test helpers to this package:

1. Keep them focused and reusable across multiple test scenarios
2. Document with inline doc comments explaining purpose and usage
3. Follow existing patterns for actor safety and `Sendable` conformance
4. Add unit tests in `TestSupportTests` to verify behavior
5. Update this README with usage examples
6. If the helper requires SearchDomain or DiscoverFeature, add it to `IntegrationTests` instead to avoid circular dependencies

## Dependencies

- **CoreModels**: Core domain models (Podcast, Episode, Folder, etc.)
- **PlaybackEngine**: Episode state management protocols

Note: TestSupport intentionally does not depend on SearchDomain or DiscoverFeature to avoid circular dependencies. Test helpers requiring those packages live in the `IntegrationTests` directory instead.

## Testing the TestSupport Package

Run tests for this package:

```bash
./scripts/run-xcode-tests.sh -t TestSupport
```

This falls back to `swift test` for the TestSupport package tests.

