import XCTest
@testable import TestSupport
import CoreModels

final class ComprehensiveMockTests: XCTestCase {
    
    // MARK: - MockPodcast Tests
    
    func testMockPodcast_CreateSample() {
        // Given: Default parameters
        // When: Creating a sample podcast
        let podcast = MockPodcast.createSample()
        
        // Then: Should have expected default values
        XCTAssertEqual(podcast.id, "pod-1")
        XCTAssertEqual(podcast.title, "Sample Podcast")
        XCTAssertEqual(podcast.author, "Sample Author")
        XCTAssertEqual(podcast.description, "Sample podcast description")
        XCTAssertEqual(podcast.artworkURL?.absoluteString, "https://example.com/artwork.jpg")
        XCTAssertEqual(podcast.feedURL.absoluteString, "https://example.com/feed.xml")
    }
    
    func testMockPodcast_CreateSampleWithCustomParameters() {
        // Given: Custom parameters
        let customId = "custom-pod"
        let customTitle = "Custom Podcast Title"
        
        // When: Creating with custom parameters
        let podcast = MockPodcast.createSample(id: customId, title: customTitle)
        
        // Then: Should use custom values
        XCTAssertEqual(podcast.id, customId)
        XCTAssertEqual(podcast.title, customTitle)
        XCTAssertEqual(podcast.author, "Sample Author") // Should keep default
    }
    
    func testMockPodcast_CreateWithFolder() {
        // Given: Folder ID
        let folderId = "test-folder"
        
        // When: Creating podcast with folder
        let podcast = MockPodcast.createWithFolder(folderId: folderId)
        
        // Then: Should be assigned to folder
        XCTAssertEqual(podcast.folderId, folderId)
        XCTAssertEqual(podcast.id, "pod-1") // Default ID
    }
    
    func testMockPodcast_CreateWithTags() {
        // Given: Tag IDs
        let tagIds = ["tech", "programming", "swift"]
        
        // When: Creating podcast with tags
        let podcast = MockPodcast.createWithTags(tagIds: tagIds)
        
        // Then: Should have assigned tags
        XCTAssertEqual(podcast.tagIds, tagIds)
        XCTAssertEqual(podcast.id, "pod-1") // Default ID
    }
    
    func testMockPodcast_CreateUnicode() {
        // Given: Unicode content support needed
        // When: Creating Unicode podcast
        let podcast = MockPodcast.createUnicode()
        
        // Then: Should preserve Unicode characters
        XCTAssertEqual(podcast.id, "pod-unicode")
        XCTAssertEqual(podcast.title, "🎧 Programação em Swift 📱")
        XCTAssertEqual(podcast.author, "João da Silva 🇧🇷")
        XCTAssertTrue(podcast.description?.contains("émojis 🚀") == true)
        XCTAssertEqual(podcast.feedURL.absoluteString, "https://example.com/feed-unicode.xml")
    }
    
    func testMockPodcast_AllMethodsProduceDifferentInstances() {
        // Given: Multiple creation methods
        // When: Creating podcasts with each method
        let sample = MockPodcast.createSample()
        let withFolder = MockPodcast.createWithFolder(folderId: "folder-1")
        let withTags = MockPodcast.createWithTags(tagIds: ["tag-1"])
        let unicode = MockPodcast.createUnicode()
        
        // Then: Should be different instances with different characteristics
        XCTAssertNotEqual(sample.id, unicode.id)
        XCTAssertNotNil(withFolder.folderId)
        XCTAssertNil(sample.folderId)
        XCTAssertFalse(withTags.tagIds.isEmpty)
        XCTAssertTrue(sample.tagIds.isEmpty)
    }
    
    // MARK: - MockEpisode Tests
    
    func testMockEpisode_CreateSample() {
        // Given: Default parameters
        // When: Creating a sample episode
        let episode = MockEpisode.createSample()
        
        // Then: Should have expected default values
        XCTAssertEqual(episode.id, "ep-1")
        XCTAssertEqual(episode.title, "Sample Episode")
        XCTAssertNil(episode.podcastID)
        XCTAssertEqual(episode.playbackPosition, 0)
        XCTAssertFalse(episode.isPlayed)
    }
    
    func testMockEpisode_CreateSampleWithCustomParameters() {
        // Given: Custom parameters
        let customId = "custom-ep"
        let customTitle = "Custom Episode"
        let podcastID = "parent-podcast"
        let playbackPosition = 1200
        let isPlayed = true
        
        // When: Creating with custom parameters
        let episode = MockEpisode.createSample(
            id: customId,
            title: customTitle,
            podcastID: podcastID,
            playbackPosition: playbackPosition,
            isPlayed: isPlayed
        )
        
        // Then: Should use custom values
        XCTAssertEqual(episode.id, customId)
        XCTAssertEqual(episode.title, customTitle)
        XCTAssertEqual(episode.podcastID, podcastID)
        XCTAssertEqual(episode.playbackPosition, playbackPosition)
        XCTAssertEqual(episode.isPlayed, isPlayed)
    }
    
    func testMockEpisode_CreateWithDuration() {
        // Given: Duration value
        let duration: TimeInterval = 3600 // 1 hour
        
        // When: Creating episode with duration
        let episode = MockEpisode.createWithDuration(duration: duration)
        
        // Then: Should have specified duration
        XCTAssertEqual(episode.duration, duration)
        XCTAssertEqual(episode.id, "ep-1") // Default ID
    }
    
    func testMockEpisode_CreateUnicode() {
        // Given: Unicode content support needed
        // When: Creating Unicode episode
        let episode = MockEpisode.createUnicode()
        
        // Then: Should preserve Unicode characters
        XCTAssertEqual(episode.id, "ep-unicode")
        XCTAssertEqual(episode.title, "🎵 Episódio especial")
        XCTAssertTrue(episode.description?.contains("acentos and émojis 🎙️") == true)
        XCTAssertEqual(episode.duration, 2400)
    }
    
    // MARK: - MockFolder Tests
    
    func testMockFolder_CreateSample() {
        // Given: Default parameters
        // When: Creating a sample folder
        let folder = MockFolder.createSample()
        
        // Then: Should have expected default values
        XCTAssertEqual(folder.id, "folder-1")
        XCTAssertEqual(folder.name, "Sample Folder")
        XCTAssertNil(folder.parentId)
        XCTAssertTrue(folder.isRoot)
    }
    
    func testMockFolder_CreateRoot() {
        // Given: Root folder parameters
        let rootId = "root-test"
        let rootName = "Test Root"
        
        // When: Creating root folder
        let folder = MockFolder.createRoot(id: rootId, name: rootName)
        
        // Then: Should be a root folder
        XCTAssertEqual(folder.id, rootId)
        XCTAssertEqual(folder.name, rootName)
        XCTAssertNil(folder.parentId)
        XCTAssertTrue(folder.isRoot)
    }
    
    func testMockFolder_CreateChild() {
        // Given: Child folder parameters
        let childId = "child-test"
        let childName = "Test Child"
        let parentId = "parent-test"
        
        // When: Creating child folder
        let folder = MockFolder.createChild(id: childId, name: childName, parentId: parentId)
        
        // Then: Should be a child folder
        XCTAssertEqual(folder.id, childId)
        XCTAssertEqual(folder.name, childName)
        XCTAssertEqual(folder.parentId, parentId)
        XCTAssertFalse(folder.isRoot)
    }
    
    func testMockFolder_CreateUnicode() {
        // Given: Unicode content support needed
        // When: Creating Unicode folder
        let folder = MockFolder.createUnicode()
        
        // Then: Should preserve Unicode characters
        XCTAssertEqual(folder.id, "folder-unicode")
        XCTAssertEqual(folder.name, "📁 Pasta Especial")
        XCTAssertNil(folder.parentId)
    }
    
    // MARK: - MockPlaylist Tests
    
    func testMockPlaylist_CreateManual() {
        // Given: Manual playlist parameters
        let episodeIds = ["ep-1", "ep-2", "ep-3"]
        
        // When: Creating manual playlist
        let playlist = MockPlaylist.createManual(episodeIds: episodeIds)
        
        // Then: Should have specified episodes
        XCTAssertEqual(playlist.id, "playlist-1")
        XCTAssertEqual(playlist.name, "Sample Playlist")
        XCTAssertEqual(playlist.episodeIds, episodeIds)
    }
    
    func testMockPlaylist_CreateManualEmpty() {
        // Given: Empty episode list
        // When: Creating empty manual playlist
        let playlist = MockPlaylist.createManual()
        
        // Then: Should be empty
        XCTAssertEqual(playlist.id, "playlist-1")
        XCTAssertTrue(playlist.episodeIds.isEmpty)
    }
    
    func testMockPlaylist_CreateSmart() {
        // Given: Smart playlist parameters
        // When: Creating smart playlist
        let smartPlaylist = MockPlaylist.createSmart()
        
        // Then: Should have expected properties
        XCTAssertEqual(smartPlaylist.id, "smart-1")
        XCTAssertEqual(smartPlaylist.name, "Smart Playlist")
    }
    
    // MARK: - MockDownloadTask Tests
    
    func testMockDownloadTask_CreateSample() {
        // Given: Default parameters
        // When: Creating sample download task
        let task = MockDownloadTask.createSample()
        
        // Then: Should have expected default values
        XCTAssertEqual(task.id, "download-1")
        XCTAssertEqual(task.episodeId, "ep-1")
        XCTAssertEqual(task.podcastId, "pod-1")
        XCTAssertEqual(task.audioURL.absoluteString, "https://example.com/episode.mp3")
        XCTAssertEqual(task.title, "Sample Episode Download")
        XCTAssertEqual(task.priority, .normal)
    }
    
    func testMockDownloadTask_CreateSampleWithCustomParameters() {
        // Given: Custom parameters
        let customId = "custom-download"
        let customEpisodeId = "custom-episode"
        let customPodcastId = "custom-podcast"
        let customURL = URL(string: "https://custom.com/audio.mp3")!
        let customTitle = "Custom Download"
        let customPriority: DownloadPriority = .high
        
        // When: Creating with custom parameters
        let task = MockDownloadTask.createSample(
            id: customId,
            episodeId: customEpisodeId,
            podcastId: customPodcastId,
            audioURL: customURL,
            title: customTitle,
            priority: customPriority
        )
        
        // Then: Should use custom values
        XCTAssertEqual(task.id, customId)
        XCTAssertEqual(task.episodeId, customEpisodeId)
        XCTAssertEqual(task.podcastId, customPodcastId)
        XCTAssertEqual(task.audioURL, customURL)
        XCTAssertEqual(task.title, customTitle)
        XCTAssertEqual(task.priority, customPriority)
    }
    
    func testMockDownloadTask_CreateWithProgress() {
        // Given: Progress configuration
        let title = "Download with Progress"
        
        // When: Creating task with progress
        let task = MockDownloadTask.createWithProgress(title: title)
        
        // Then: Should have progress configuration
        XCTAssertEqual(task.id, "download-progress")
        XCTAssertEqual(task.title, title)
        XCTAssertEqual(task.priority, .normal)
    }
    
    // MARK: - Integration Tests
    
    func testMockIntegration_PodcastWithEpisodes() {
        // Given: A podcast and related episodes
        let podcast = MockPodcast.createSample(id: "integration-pod", title: "Integration Podcast")
        let episode1 = MockEpisode.createSample(id: "int-ep-1", podcastID: podcast.id)
        let episode2 = MockEpisode.createSample(id: "int-ep-2", podcastID: podcast.id)
        
        // When: Using them together
        let episodeIds = [episode1.id, episode2.id]
        let playlist = MockPlaylist.createManual(id: "int-playlist", episodeIds: episodeIds)
        
        // Then: Should work together coherently
        XCTAssertEqual(episode1.podcastID, podcast.id)
        XCTAssertEqual(episode2.podcastID, podcast.id)
        XCTAssertEqual(playlist.episodeIds.count, 2)
        XCTAssertTrue(playlist.episodeIds.contains(episode1.id))
        XCTAssertTrue(playlist.episodeIds.contains(episode2.id))
    }
    
    func testMockIntegration_FolderHierarchyWithPodcasts() {
        // Given: A folder hierarchy
        let rootFolder = MockFolder.createRoot(id: "tech", name: "Technology")
        let childFolder = MockFolder.createChild(id: "apple", name: "Apple", parentId: rootFolder.id)
        
        // When: Creating podcasts in folders
        let rootPodcast = MockPodcast.createWithFolder(id: "general-tech", folderId: rootFolder.id)
        let childPodcast = MockPodcast.createWithFolder(id: "wwdc", folderId: childFolder.id)
        
        // Then: Should maintain referential integrity
        XCTAssertEqual(rootPodcast.folderId, rootFolder.id)
        XCTAssertEqual(childPodcast.folderId, childFolder.id)
        XCTAssertEqual(childFolder.parentId, rootFolder.id)
    }
    
    func testMockIntegration_DownloadTasksForEpisodes() {
        // Given: Episodes and download tasks
        let episode1 = MockEpisode.createWithDuration(id: "dl-ep-1", duration: 3600.0)
        let episode2 = MockEpisode.createWithDuration(id: "dl-ep-2", duration: 2400.0)
        
        // When: Creating download tasks for episodes
        let task1 = MockDownloadTask.createSample(
            id: "dl-task-1", 
            episodeId: episode1.id, 
            title: "Task for Episode 1", 
            priority: .high
        )
        let task2 = MockDownloadTask.createWithProgress(
            id: "dl-task-2", 
            episodeId: episode2.id, 
            title: "Task for Episode 2"
        )
        
        // Then: Should maintain episode relationships
        XCTAssertEqual(task1.episodeId, episode1.id)
        XCTAssertEqual(task2.episodeId, episode2.id)
        XCTAssertEqual(task1.priority, .high)
        XCTAssertEqual(task2.priority, .normal)
    }
    
    // MARK: - Edge Cases and Validation
    
    func testMockDataValidation_AllMockTypesAreValid() {
        // Given: All mock creation methods
        // When: Creating instances of all types
        let podcast = MockPodcast.createSample()
        let episode = MockEpisode.createSample()
        let folder = MockFolder.createSample()
        let playlist = MockPlaylist.createManual()
        let smartPlaylist = MockPlaylist.createSmart()
        let downloadTask = MockDownloadTask.createSample()
        
        // Then: All should be valid model instances
        XCTAssertFalse(podcast.id.isEmpty)
        XCTAssertFalse(podcast.title.isEmpty)
        XCTAssertFalse(episode.id.isEmpty)
        XCTAssertFalse(episode.title.isEmpty)
        XCTAssertFalse(folder.id.isEmpty)
        XCTAssertFalse(folder.name.isEmpty)
        XCTAssertFalse(playlist.id.isEmpty)
        XCTAssertFalse(playlist.name.isEmpty)
        XCTAssertFalse(smartPlaylist.id.isEmpty)
        XCTAssertFalse(smartPlaylist.name.isEmpty)
        XCTAssertFalse(downloadTask.id.isEmpty)
        XCTAssertFalse(downloadTask.episodeId.isEmpty)
    }
    
    func testMockDataConsistency_RepeatedCreation() {
        // Given: Creating same mock multiple times
        // When: Creating multiple instances with same parameters
        let podcast1 = MockPodcast.createSample(id: "same-id", title: "Same Title")
        let podcast2 = MockPodcast.createSample(id: "same-id", title: "Same Title")
        
        // Then: Should produce equivalent but separate instances
        XCTAssertEqual(podcast1.id, podcast2.id)
        XCTAssertEqual(podcast1.title, podcast2.title)
        XCTAssertEqual(podcast1.feedURL, podcast2.feedURL)
    }
    
    func testMockUnicodeConsistency_AllTypesSupported() {
        // Given: Unicode content across all mock types
        // When: Creating Unicode instances
        let unicodePodcast = MockPodcast.createUnicode()
        let unicodeEpisode = MockEpisode.createUnicode()
        let unicodeFolder = MockFolder.createUnicode()
        
        // Then: All should preserve Unicode correctly
        XCTAssertTrue(unicodePodcast.title.contains("🎧"))
        XCTAssertTrue(unicodePodcast.author?.contains("🇧🇷") == true)
        XCTAssertTrue(unicodeEpisode.title.contains("🎵"))
        XCTAssertTrue(unicodeEpisode.description?.contains("🎙️") == true)
        XCTAssertTrue(unicodeFolder.name.contains("📁"))
    }
}
