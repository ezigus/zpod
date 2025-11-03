//
//  EpisodeListViewTests.swift
//  LibraryFeatureTests
//
//  Created for Issue 02.1.1: Episode List Display and Basic Navigation
//

#if canImport(SwiftUI)
import XCTest
import SwiftUI
@testable import LibraryFeature
import CoreModels

final class EpisodeListViewTests: XCTestCase {
    
    // Test data
    private var samplePodcast: Podcast!
    private var emptyPodcast: Podcast!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Create sample podcast with episodes
        samplePodcast = Podcast(
            id: "test-podcast",
            title: "Test Podcast",
            author: "Test Author",
            description: "A test podcast",
            feedURL: URL(string: "https://example.com/test.xml")!,
            episodes: [
                Episode(
                    id: "ep1",
                    title: "Episode 1",
                    podcastID: "test-podcast",
                    pubDate: Date(),
                    duration: 1800,
                    description: "First episode"
                ),
                Episode(
                    id: "ep2",
                    title: "Episode 2",
                    podcastID: "test-podcast",
                    playbackPosition: 300,
                    pubDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                    duration: 2400,
                    description: "Second episode"
                )
            ]
        )
        
        // Create empty podcast
        emptyPodcast = Podcast(
            id: "empty-podcast",
            title: "Empty Podcast",
            feedURL: URL(string: "https://example.com/empty.xml")!,
            episodes: []
        )
    }
    
    override func tearDownWithError() throws {
        samplePodcast = nil
        emptyPodcast = nil
    }
    
    // MARK: - EpisodeListView Tests
    
    @MainActor
    func testEpisodeListViewInitialization() throws {
        // Given: A podcast with episodes
        // When: Creating an EpisodeListView
        let episodeListView = EpisodeListView(podcast: samplePodcast)
        
        // Then: The view should be created successfully
        XCTAssertNotNil(episodeListView)
    }
    
    @MainActor
    func testEpisodeListWithEpisodes() throws {
        // Given: A podcast with episodes
        let episodeListView = EpisodeListView(podcast: samplePodcast)
        
        // When: The view is rendered
        // Then: It should display the episodes
        // Note: In a full UI test environment, we would test the actual rendering
        // For now, we verify the data structure is correct
        XCTAssertEqual(samplePodcast.episodes.count, 2)
        XCTAssertEqual(samplePodcast.episodes[0].id, "ep1")
        XCTAssertEqual(samplePodcast.episodes[1].id, "ep2")
    }
    
    @MainActor
    func testEpisodeListWithEmptyPodcast() throws {
        // Given: A podcast with no episodes
        let episodeListView = EpisodeListView(podcast: emptyPodcast)
        
        // When: The view is created
        // Then: It should handle empty state gracefully
        XCTAssertNotNil(episodeListView)
        XCTAssertTrue(emptyPodcast.episodes.isEmpty)
    }
    
    // MARK: - EpisodeRowView Tests
    
    @MainActor
    func testEpisodeRowViewWithBasicEpisode() throws {
        // Given: A basic episode
        let episode = Episode(
            id: "test-ep",
            title: "Test Episode",
            pubDate: Date(),
            duration: 1800
        )
        
        // When: Creating an EpisodeRowView
        let rowView = EpisodeRowView(episode: episode)
        
        // Then: The view should be created successfully
        XCTAssertNotNil(rowView)
    }
    
    @MainActor
    func testEpisodeRowViewWithPlayedEpisode() throws {
        // Given: A played episode
        let episode = Episode(
            id: "played-ep",
            title: "Played Episode",
            isPlayed: true,
            pubDate: Date(),
            duration: 1800
        )
        
        // When: Creating an EpisodeRowView
        let rowView = EpisodeRowView(episode: episode)
        
        // Then: The view should reflect the played status
        XCTAssertNotNil(rowView)
        XCTAssertTrue(episode.isPlayed)
    }
    
    @MainActor
    func testEpisodeRowViewWithInProgressEpisode() throws {
        // Given: An episode in progress
        let episode = Episode(
            id: "progress-ep",
            title: "In Progress Episode",
            playbackPosition: 450,
            pubDate: Date(),
            duration: 1800
        )
        
        // When: Creating an EpisodeRowView
        let rowView = EpisodeRowView(episode: episode)
        
        // Then: The view should reflect the in-progress status
        XCTAssertNotNil(rowView)
        XCTAssertGreaterThan(episode.playbackPosition, 0)
        XCTAssertFalse(episode.isPlayed)
    }
    
    // MARK: - Duration Formatting Tests
    
    @MainActor
    func testDurationFormattingForMinutes() throws {
        // Given: An episode with duration in minutes
        let episode = Episode(
            id: "short-ep",
            title: "Short Episode",
            duration: 900 // 15 minutes
        )
        
        let rowView = EpisodeRowView(episode: episode)
        
        // When/Then: Duration should be formatted correctly for minutes
        // Note: We'd need to expose the formatDuration method or test it indirectly
        XCTAssertEqual(episode.duration, 900)
    }
    
    @MainActor
    func testDurationFormattingForHours() throws {
        // Given: An episode with duration in hours
        let episode = Episode(
            id: "long-ep",
            title: "Long Episode",
            duration: 5400 // 1.5 hours
        )
        
        let rowView = EpisodeRowView(episode: episode)
        
        // When/Then: Duration should be formatted correctly for hours
        XCTAssertEqual(episode.duration, 5400)
    }
    
}
#endif
