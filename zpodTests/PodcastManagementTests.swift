import XCTest
import TestSupport
@testable import zpodLib

/// Tests for podcast management functionality including CRUD operations and subscription management
///
/// **Specifications Covered**: `spec/discovery.md` - Podcast management sections
/// - Podcast subscription and unsubscription workflows
/// - CRUD operations for podcast metadata and settings
/// - Feed parsing integration and podcast discovery
/// - Subscription state management and persistence
final class PodcastManagementTests: XCTestCase {
    
    // MARK: - Test Fixtures
    private var podcastManager: InMemoryPodcastManager!
    private var samplePodcasts: [Podcast]!

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        podcastManager = InMemoryPodcastManager()
        samplePodcasts = [
            Podcast(
                id: "podcast1",
                title: "Tech News",
                description: "Latest technology news",
                feedURL: URL(string: "https://example.com/tech.xml")!,
                folderId: "folder1",
                tagIds: ["tag1", "tag2"]
            ),
            Podcast(
                id: "podcast2",
                title: "Science Today",
                description: "Daily science updates",
                feedURL: URL(string: "https://example.com/science.xml")!
            ),
            Podcast(
                id: "podcast3",
                title: "Music Reviews",
                description: "Album and track reviews",
                feedURL: URL(string: "https://example.com/music.xml")!,
                folderId: "folder1",
                tagIds: ["tag1"]
            )
        ]
    }

    override func tearDown() {
        podcastManager = nil
        samplePodcasts = nil
        super.tearDown()
    }

    // MARK: - Basic CRUD Operations Tests
    // Covers: Basic podcast management from discovery spec

    func testAddValidPodcast() {
        // Given: Valid podcast
        let podcast = samplePodcasts[0]
        
        // When: Adding podcast
        podcastManager.add(podcast)
        
        // Then: Podcast should be stored
        let found = podcastManager.find(id: podcast.id)
        XCTAssertEqual(found, podcast)
        XCTAssertEqual(podcastManager.all().count, 1)
    }

    func testAddDuplicatePodcast() {
        // Given: Existing podcast
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)
        
        // When: Adding same podcast again
        podcastManager.add(podcast)
        
        // Then: Should not create duplicate
        XCTAssertEqual(podcastManager.all().count, 1)
    }

    func testUpdateExistingPodcast() {
        // Given: Existing podcast
        let originalPodcast = samplePodcasts[0]
        podcastManager.add(originalPodcast)
        
        // When: Updating podcast
        let updatedPodcast = Podcast(
            id: originalPodcast.id,
            title: "Updated Tech News",
            description: "Updated description",
            feedURL: originalPodcast.feedURL,
            folderId: originalPodcast.folderId,
            tagIds: originalPodcast.tagIds
        )
        podcastManager.update(updatedPodcast)
        
        // Then: Podcast should be updated
        let found = podcastManager.find(id: originalPodcast.id)
        XCTAssertEqual(found?.title, "Updated Tech News")
        XCTAssertEqual(found?.description, "Updated description")
    }

    func testUpdateNonexistentPodcast() {
        // Given: Empty podcast manager
        // When: Updating non-existent podcast
        let podcast = samplePodcasts[0]
        podcastManager.update(podcast)
        
        // Then: Podcast should not be added
        XCTAssertNil(podcastManager.find(id: podcast.id))
        XCTAssertTrue(podcastManager.all().isEmpty)
    }

    func testRemoveExistingPodcast() {
        // Given: Existing podcast
        let podcast = samplePodcasts[0]
        podcastManager.add(podcast)
        
        // When: Removing podcast
        podcastManager.remove(id: podcast.id)
        
        // Then: Podcast should be removed
        XCTAssertNil(podcastManager.find(id: podcast.id))
        XCTAssertTrue(podcastManager.all().isEmpty)
    }

    func testRemoveNonexistentPodcast() {
        // Given: Empty podcast manager
        // When: Removing non-existent podcast
        podcastManager.remove(id: "nonexistent")
        
        // Then: Should not throw error
        XCTAssertTrue(podcastManager.all().isEmpty)
    }

    // MARK: - Subscription Management Tests
    // Covers: Subscription workflows from discovery spec

    func testSubscribeToPodcast() {
        // Given: Unsubscribed podcast
        var podcast = samplePodcasts[0]
        podcast = podcast.withSubscriptionStatus(false)
        podcastManager.add(podcast)
        
        // When: Subscribing to podcast
        podcastManager.subscribe(to: podcast.id)
        
        // Then: Podcast should be subscribed
        let updated = podcastManager.find(id: podcast.id)
        XCTAssertTrue(updated?.isSubscribed ?? false)
    }

    func testUnsubscribeFromPodcast() {
        // Given: Subscribed podcast
        var podcast = samplePodcasts[0]
        podcast = podcast.withSubscriptionStatus(true)
        podcastManager.add(podcast)
        
        // When: Unsubscribing from podcast
        podcastManager.unsubscribe(from: podcast.id)
        
        // Then: Podcast should be unsubscribed
        let updated = podcastManager.find(id: podcast.id)
        XCTAssertFalse(updated?.isSubscribed ?? true)
    }

    func testGetSubscribedPodcasts() {
        // Given: Mix of subscribed and unsubscribed podcasts
        samplePodcasts.enumerated().forEach { index, podcast in
            let isSubscribed = index % 2 == 0 // Subscribe to every other podcast
            let updatedPodcast = podcast.withSubscriptionStatus(isSubscribed)
            podcastManager.add(updatedPodcast)
        }
        
        // When: Getting subscribed podcasts
        let subscribedPodcasts = podcastManager.getSubscribedPodcasts()
        
        // Then: Should return only subscribed podcasts
        XCTAssertEqual(subscribedPodcasts.count, 2) // 2 out of 3 are subscribed
        XCTAssertTrue(subscribedPodcasts.allSatisfy { $0.isSubscribed })
    }

    // MARK: - Search and Filtering Tests
    // Covers: Podcast discovery and filtering from discovery spec

    func testFindPodcastsByTitle() {
        // Given: Podcasts with different titles
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Searching by title
        let newsResults = podcastManager.findByTitle(containing: "News")
        let scienceResults = podcastManager.findByTitle(containing: "Science")
        let musicResults = podcastManager.findByTitle(containing: "Music")
        
        // Then: Should return matching podcasts
        XCTAssertEqual(newsResults.count, 1)
        XCTAssertEqual(newsResults.first?.title, "Tech News")
        
        XCTAssertEqual(scienceResults.count, 1)
        XCTAssertEqual(scienceResults.first?.title, "Science Today")
        
        XCTAssertEqual(musicResults.count, 1)
        XCTAssertEqual(musicResults.first?.title, "Music Reviews")
    }

    func testFindPodcastsByFolder() {
        // Given: Podcasts in different folders
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Finding by folder
        let folder1Podcasts = podcastManager.findByFolder(folderId: "folder1")
        let unorganizedPodcasts = podcastManager.findByFolder(folderId: nil)
        
        // Then: Should return podcasts in specified folder
        XCTAssertEqual(folder1Podcasts.count, 2)
        XCTAssertTrue(folder1Podcasts.contains { $0.title == "Tech News" })
        XCTAssertTrue(folder1Podcasts.contains { $0.title == "Music Reviews" })
        
        XCTAssertEqual(unorganizedPodcasts.count, 1)
        XCTAssertEqual(unorganizedPodcasts.first?.title, "Science Today")
    }

    func testFindPodcastsByTag() {
        // Given: Podcasts with different tags
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Finding by tag
        let tag1Podcasts = podcastManager.findByTag(tagId: "tag1")
        let tag2Podcasts = podcastManager.findByTag(tagId: "tag2")
        let untaggedPodcasts = podcastManager.findByTag(tagId: "nonexistent")
        
        // Then: Should return podcasts with specified tag
        XCTAssertEqual(tag1Podcasts.count, 2)
        XCTAssertTrue(tag1Podcasts.contains { $0.title == "Tech News" })
        XCTAssertTrue(tag1Podcasts.contains { $0.title == "Music Reviews" })
        
        XCTAssertEqual(tag2Podcasts.count, 1)
        XCTAssertEqual(tag2Podcasts.first?.title, "Tech News")
        
        XCTAssertTrue(untaggedPodcasts.isEmpty)
    }

    func testFindPodcastsByFeedURL() {
        // Given: Podcasts with different feed URLs
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // When: Finding by feed URL
        let techFeedURL = URL(string: "https://example.com/tech.xml")!
        let found = podcastManager.findByFeedURL(techFeedURL)
        
        // Then: Should return podcast with matching feed URL
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "Tech News")
    }

    // MARK: - Podcast Metadata Tests
    // Covers: Podcast metadata management from discovery spec

    func testPodcastInitializationWithMinimalData() {
        // Given: Minimal podcast data
        let id = "minimal-podcast"
        let title = "Minimal Podcast"
        let feedURL = URL(string: "https://example.com/minimal.xml")!
        
        // When: Creating podcast
        let podcast = Podcast(id: id, title: title, feedURL: feedURL)
        
        // Then: Should have proper defaults
        XCTAssertEqual(podcast.id, id)
        XCTAssertEqual(podcast.title, title)
        XCTAssertEqual(podcast.feedURL, feedURL)
        XCTAssertTrue(podcast.description.isEmpty)
        XCTAssertTrue(podcast.categories.isEmpty)
        XCTAssertTrue(podcast.episodes.isEmpty)
        XCTAssertFalse(podcast.isSubscribed)
        XCTAssertNil(podcast.folderId)
        XCTAssertTrue(podcast.tagIds.isEmpty)
    }

    func testPodcastInitializationWithCompleteData() {
        // Given: Complete podcast data
        let id = "complete-podcast"
        let title = "Complete Podcast"
        let description = "A podcast with all metadata"
        let feedURL = URL(string: "https://example.com/complete.xml")!
        let categories = ["Technology", "Programming"]
        let dateAdded = Date()
        let folderId = "tech-folder"
        let tagIds = ["tech", "programming"]
        
        // When: Creating podcast
        let podcast = Podcast(
            id: id,
            title: title,
            description: description,
            feedURL: feedURL,
            categories: categories,
            dateAdded: dateAdded,
            folderId: folderId,
            tagIds: tagIds
        )
        
        // Then: All properties should be set correctly
        XCTAssertEqual(podcast.id, id)
        XCTAssertEqual(podcast.title, title)
        XCTAssertEqual(podcast.description, description)
        XCTAssertEqual(podcast.feedURL, feedURL)
        XCTAssertEqual(podcast.categories, categories)
        XCTAssertEqual(podcast.dateAdded, dateAdded)
        XCTAssertEqual(podcast.folderId, folderId)
        XCTAssertEqual(podcast.tagIds, tagIds)
    }

    func testPodcastCodable() throws {
        // Given: Podcast with complete data
        let podcast = samplePodcasts[0]
        
        // When: Encoding and decoding
        let data = try JSONEncoder().encode(podcast)
        let decoded = try JSONDecoder().decode(Podcast.self, from: data)
        
        // Then: Podcast should be preserved
        XCTAssertEqual(podcast, decoded)
    }

    // MARK: - Episode Management Tests
    // Covers: Episode integration from discovery spec

    func testAddEpisodeToPodcast() {
        // Given: Podcast with no episodes
        var podcast = samplePodcasts[0]
        podcast = podcast.withEpisodes([])
        podcastManager.add(podcast)
        
        let episode = Episode(
            id: "episode1",
            title: "Test Episode",
            podcastID: podcast.id,
            playbackPosition: 0,
            isPlayed: false,
            pubDate: Date(),
            duration: 1800,
            description: "A test episode",
            audioURL: URL(string: "https://example.com/episode1.mp3")
        )
        
        // When: Adding episode to podcast
        podcastManager.addEpisode(episode, to: podcast.id)
        
        // Then: Episode should be added
        let updated = podcastManager.find(id: podcast.id)
        XCTAssertEqual(updated?.episodes.count, 1)
        XCTAssertEqual(updated?.episodes.first?.id, episode.id)
    }

    func testUpdateEpisodeInPodcast() {
        // Given: Podcast with episode
        let episode = Episode(
            id: "episode1",
            title: "Original Title",
            podcastID: "podcast1",
            playbackPosition: 0,
            isPlayed: false,
            pubDate: Date(),
            duration: 1800,
            description: "Original description",
            audioURL: URL(string: "https://example.com/episode1.mp3")
        )
        
        var podcast = samplePodcasts[0]
        podcast = podcast.withEpisodes([episode])
        podcastManager.add(podcast)
        
        // When: Updating episode
        let updatedEpisode = Episode(
            id: episode.id,
            title: "Updated Title",
            podcastID: episode.podcastID,
            playbackPosition: episode.playbackPosition,
            isPlayed: episode.isPlayed,
            pubDate: episode.pubDate,
            duration: episode.duration,
            description: "Updated description",
            audioURL: episode.audioURL
        )
        
        podcastManager.updateEpisode(updatedEpisode, in: podcast.id)
        
        // Then: Episode should be updated
        let updated = podcastManager.find(id: podcast.id)
        let foundEpisode = updated?.episodes.first { $0.id == episode.id }
        XCTAssertEqual(foundEpisode?.title, "Updated Title")
        XCTAssertEqual(foundEpisode?.description, "Updated description")
    }

    func testRemoveEpisodeFromPodcast() {
        // Given: Podcast with episodes
        let episode1 = Episode(
            id: "episode1",
            title: "Episode 1",
            podcastID: "podcast1",
            playbackPosition: 0,
            isPlayed: false,
            pubDate: Date(),
            duration: 1800,
            description: "First episode",
            audioURL: URL(string: "https://example.com/episode1.mp3")
        )
        
        let episode2 = Episode(
            id: "episode2",
            title: "Episode 2",
            podcastID: "podcast1",
            playbackPosition: 0,
            isPlayed: false,
            pubDate: Date(),
            duration: 2400,
            description: "Second episode",
            audioURL: URL(string: "https://example.com/episode2.mp3")
        )
        
        var podcast = samplePodcasts[0]
        podcast = podcast.withEpisodes([episode1, episode2])
        podcastManager.add(podcast)
        
        // When: Removing episode
        podcastManager.removeEpisode(id: episode1.id, from: podcast.id)
        
        // Then: Episode should be removed
        let updated = podcastManager.find(id: podcast.id)
        XCTAssertEqual(updated?.episodes.count, 1)
        XCTAssertEqual(updated?.episodes.first?.id, episode2.id)
    }

    // MARK: - Data Validation Tests
    // Covers: Input validation and error handling from discovery spec

    func testPodcastValidation_EmptyTitle() {
        // Given: Podcast with empty title
        let podcast = Podcast(
            id: "invalid-podcast",
            title: "",
            feedURL: URL(string: "https://example.com/feed.xml")!
        )
        
        // When: Adding invalid podcast
        podcastManager.add(podcast)
        
        // Then: Podcast should still be added (title validation is lenient)
        let found = podcastManager.find(id: podcast.id)
        XCTAssertNotNil(found)
    }

    func testPodcastValidation_InvalidFeedURL() {
        // Given: Valid podcast data except for feed URL format
        // Note: Podcast initializer requires valid URL, so we test with edge case URL
        let edgeCaseURL = URL(string: "file://local-file.xml")!
        let podcast = Podcast(
            id: "edge-case-podcast",
            title: "Edge Case Podcast",
            feedURL: edgeCaseURL
        )
        
        // When: Adding podcast with edge case URL
        podcastManager.add(podcast)
        
        // Then: Podcast should be added (URL validation is permissive)
        let found = podcastManager.find(id: podcast.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.feedURL, edgeCaseURL)
    }

    // MARK: - Performance Tests
    // Covers: Performance considerations from discovery spec

    func testBulkOperationsPerformance() {
        // Given: Large number of podcasts
        let bulkPodcasts = (0..<1000).map { index in
            Podcast(
                id: "podcast\(index)",
                title: "Podcast \(index)",
                description: "Description for podcast \(index)",
                feedURL: URL(string: "https://example.com/podcast\(index).xml")!
            )
        }
        
        // When: Adding many podcasts
        measure {
            bulkPodcasts.forEach { podcastManager.add($0) }
        }
        
        // Then: All podcasts should be added
        XCTAssertEqual(podcastManager.all().count, 1000)
    }

    func testSearchPerformance() {
        // Given: Large number of podcasts
        let bulkPodcasts = (0..<1000).map { index in
            Podcast(
                id: "podcast\(index)",
                title: "Tech Podcast \(index)",
                description: "Technology podcast number \(index)",
                feedURL: URL(string: "https://example.com/tech\(index).xml")!,
                folderId: index % 2 == 0 ? "tech" : "other"
            )
        }
        
        bulkPodcasts.forEach { podcastManager.add($0) }
        
        // When: Searching through many podcasts
        measure {
            let _ = podcastManager.findByTitle(containing: "Tech")
            let _ = podcastManager.findByFolder(folderId: "tech")
        }
        
        // Then: Search should complete within reasonable time
        let techResults = podcastManager.findByTitle(containing: "Tech")
        XCTAssertEqual(techResults.count, 1000)
    }

    // MARK: - Acceptance Criteria Tests
    // Covers: Complete podcast management workflows from discovery specification

    func testAcceptanceCriteria_PodcastSubscriptionWorkflow() {
        // Given: User discovers a new podcast
        let newPodcast = Podcast(
            id: "new-discovery",
            title: "Newly Discovered Podcast",
            description: "A podcast discovered through search",
            feedURL: URL(string: "https://example.com/new-discovery.xml")!
        )
        
        // When: User subscribes to podcast and organizes it
        podcastManager.add(newPodcast)
        podcastManager.subscribe(to: newPodcast.id)
        
        // Organize podcast in folder and with tags
        let organizedPodcast = Podcast(
            id: newPodcast.id,
            title: newPodcast.title,
            description: newPodcast.description,
            feedURL: newPodcast.feedURL,
            folderId: "tech",
            tagIds: ["programming", "education"]
        )
        podcastManager.update(organizedPodcast)
        
        // Then: Podcast should be properly subscribed and organized
        let result = podcastManager.find(id: newPodcast.id)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isSubscribed ?? false)
        XCTAssertEqual(result?.folderId, "tech")
        XCTAssertEqual(result?.tagIds, ["programming", "education"])
    }

    func testAcceptanceCriteria_PodcastLibraryManagement() {
        // Given: User has a library of podcasts
        samplePodcasts.forEach { podcastManager.add($0) }
        
        // Subscribe to some podcasts
        podcastManager.subscribe(to: samplePodcasts[0].id)
        podcastManager.subscribe(to: samplePodcasts[1].id)
        
        // When: User manages their library
        let subscribedPodcasts = podcastManager.getSubscribedPodcasts()
        let folderPodcasts = podcastManager.findByFolder(folderId: "folder1")
        let taggedPodcasts = podcastManager.findByTag(tagId: "tag1")
        
        // Then: Library should be properly organized and accessible
        XCTAssertEqual(subscribedPodcasts.count, 2)
        XCTAssertEqual(folderPodcasts.count, 2)
        XCTAssertEqual(taggedPodcasts.count, 2)
        
        // User can easily find content
        let techPodcasts = podcastManager.findByTitle(containing: "Tech")
        XCTAssertEqual(techPodcasts.count, 1)
        XCTAssertEqual(techPodcasts.first?.title, "Tech News")
    }

    func testAcceptanceCriteria_PodcastMetadataUpdate() {
        // Given: Existing podcast with outdated information
        let originalPodcast = samplePodcasts[0]
        podcastManager.add(originalPodcast)
        
        // When: Feed is refreshed with updated metadata
        let updatedPodcast = Podcast(
            id: originalPodcast.id,
            title: "Updated Tech News Daily",
            description: "Updated daily technology news and analysis",
            feedURL: originalPodcast.feedURL,
            categories: ["Technology", "News", "Business"],
            dateAdded: originalPodcast.dateAdded,
            folderId: originalPodcast.folderId,
            tagIds: originalPodcast.tagIds
        )
        
        podcastManager.update(updatedPodcast)
        
        // Then: Podcast metadata should be updated while preserving organization
        let result = podcastManager.find(id: originalPodcast.id)
        XCTAssertEqual(result?.title, "Updated Tech News Daily")
        XCTAssertEqual(result?.description, "Updated daily technology news and analysis")
        XCTAssertEqual(result?.categories, ["Technology", "News", "Business"])
        XCTAssertEqual(result?.folderId, originalPodcast.folderId) // Organization preserved
        XCTAssertEqual(result?.tagIds, originalPodcast.tagIds) // Organization preserved
    }
}

// MARK: - Test Support Extensions
extension Podcast {
    func withSubscriptionStatus(_ isSubscribed: Bool) -> Podcast {
        return Podcast(
            id: self.id,
            title: self.title,
            description: self.description,
            feedURL: self.feedURL,
            categories: self.categories,
            episodes: self.episodes,
            isSubscribed: isSubscribed,
            dateAdded: self.dateAdded,
            folderId: self.folderId,
            tagIds: self.tagIds
        )
    }
    
    func withEpisodes(_ episodes: [Episode]) -> Podcast {
        return Podcast(
            id: self.id,
            title: self.title,
            description: self.description,
            feedURL: self.feedURL,
            categories: self.categories,
            episodes: episodes,
            isSubscribed: self.isSubscribed,
            dateAdded: self.dateAdded,
            folderId: self.folderId,
            tagIds: self.tagIds
        )
    }
}

extension InMemoryPodcastManager {
    func findByTitle(containing searchTerm: String) -> [Podcast] {
        return all().filter { $0.title.localizedCaseInsensitiveContains(searchTerm) }
    }
    
    func subscribe(to podcastId: String) {
        if let podcast = find(id: podcastId) {
            let subscribedPodcast = podcast.withSubscriptionStatus(true)
            update(subscribedPodcast)
        }
    }
    
    func unsubscribe(from podcastId: String) {
        if let podcast = find(id: podcastId) {
            let unsubscribedPodcast = podcast.withSubscriptionStatus(false)
            update(unsubscribedPodcast)
        }
    }
    
    func getSubscribedPodcasts() -> [Podcast] {
        return all().filter { $0.isSubscribed }
    }
    
    func addEpisode(_ episode: Episode, to podcastId: String) {
        if let podcast = find(id: podcastId) {
            var updatedEpisodes = podcast.episodes
            updatedEpisodes.append(episode)
            let updatedPodcast = podcast.withEpisodes(updatedEpisodes)
            update(updatedPodcast)
        }
    }
    
    func updateEpisode(_ episode: Episode, in podcastId: String) {
        if let podcast = find(id: podcastId) {
            var updatedEpisodes = podcast.episodes
            if let index = updatedEpisodes.firstIndex(where: { $0.id == episode.id }) {
                updatedEpisodes[index] = episode
                let updatedPodcast = podcast.withEpisodes(updatedEpisodes)
                update(updatedPodcast)
            }
        }
    }
    
    func removeEpisode(id episodeId: String, from podcastId: String) {
        if let podcast = find(id: podcastId) {
            let updatedEpisodes = podcast.episodes.filter { $0.id != episodeId }
            let updatedPodcast = podcast.withEpisodes(updatedEpisodes)
            update(updatedPodcast)
        }
    }
    
    func findByFeedURL(_ feedURL: URL) -> Podcast? {
        return all().first { $0.feedURL == feedURL }
    }
}