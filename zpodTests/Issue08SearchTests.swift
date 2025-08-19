import XCTest
@testable import zpod

final class Issue08SearchTests: XCTestCase {
  // MARK: - Fixtures
  
  private let samplePodcast1 = Podcast(
    id: "tech-podcast",
    title: "Swift Technology Podcast",
    author: "John Developer",
    description: "A podcast about Swift programming and iOS development",
    feedURL: URL(string: "https://example.com/tech.xml")!,
    categories: ["Technology", "Programming"]
  )
  
  private let samplePodcast2 = Podcast(
    id: "cooking-show",
    title: "Cooking Adventures",
    author: "Chef Maria",
    description: "Exploring cuisine from around the world",
    feedURL: URL(string: "https://example.com/cooking.xml")!,
    categories: ["Food", "Lifestyle"]
  )
  
  private let sampleEpisode1 = Episode(
    id: "ep-swift-intro",
    title: "Introduction to Swift Programming",
    description: "Learn the basics of Swift language and iOS development",
    podcastId: "tech-podcast"
  )
  
  private let sampleEpisode2 = Episode(
    id: "ep-pasta-making",
    title: "Making Perfect Pasta",
    description: "Traditional Italian techniques for homemade pasta",
    podcastId: "cooking-show"
  )
  
  private let sampleEpisode3 = Episode(
    id: "ep-swift-advanced",
    title: "Advanced Swift Features",
    description: "Deep dive into Swift concurrency and async/await",
    podcastId: "tech-podcast"
  )
  
  // MARK: - Test Doubles
  
  private final class MockPodcastIndexSource: SearchIndexSource {
    let podcasts: [Podcast]
    
    init(podcasts: [Podcast]) {
      self.podcasts = podcasts
    }
    
    func documents() -> [SearchableDocument] {
      return podcasts.map { podcast in
        SearchableDocument(
          id: podcast.id,
          type: .podcast,
          fields: [
            .title: podcast.title,
            .author: podcast.author ?? "",
            .description: podcast.description ?? ""
          ],
          sourceObject: podcast
        )
      }
    }
  }
  
  private final class MockEpisodeIndexSource: SearchIndexSource {
    let episodes: [Episode]
    
    init(episodes: [Episode]) {
      self.episodes = episodes
    }
    
    func documents() -> [SearchableDocument] {
      return episodes.map { episode in
        SearchableDocument(
          id: episode.id,
          type: .episode,
          fields: [
            .title: episode.title,
            .description: episode.description ?? ""
          ],
          sourceObject: episode
        )
      }
    }
  }
  
  // MARK: - Tokenizer Tests
  
  func test_tokenizer_basicWordSplitting() {
    // Given
    let tokenizer = Tokenizer()
    
    // When
    let tokens = tokenizer.tokenize("Hello, World!")
    
    // Then
    XCTAssertEqual(tokens, ["hello", "world"])
  }
  
  func test_tokenizer_removesStopWords() {
    // Given
    let tokenizer = Tokenizer()
    
    // When
    let tokens = tokenizer.tokenize("the quick brown fox")
    
    // Then
    XCTAssertEqual(tokens, ["quick", "brown", "fox"])
  }
  
  func test_tokenizer_handlesPunctuation() {
    // Given
    let tokenizer = Tokenizer()
    
    // When
    let tokens = tokenizer.tokenize("Swift's async/await features!")
    
    // Then
    XCTAssertEqual(tokens, ["swift", "async", "await", "features"])
  }
  
  func test_tokenizer_emptyStringReturnsEmptyArray() {
    // Given
    let tokenizer = Tokenizer()
    
    // When
    let tokens = tokenizer.tokenize("")
    
    // Then
    XCTAssertTrue(tokens.isEmpty)
  }
  
  // MARK: - SearchIndex Tests
  
  func test_searchIndex_addAndFindDocument() {
    // Given
    let index = SearchIndex()
    let document = SearchableDocument(
      id: "test-doc",
      type: .podcast,
      fields: [.title: "Swift Programming"],
      sourceObject: samplePodcast1
    )
    
    // When
    index.addDocument(document)
    let results = index.findDocuments(for: "swift")
    
    // Then
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.id, "test-doc")
  }
  
  func test_searchIndex_multipleTermsInDocument() {
    // Given
    let index = SearchIndex()
    let document = SearchableDocument(
      id: "test-doc",
      type: .episode,
      fields: [.title: "Swift Programming Tutorial"],
      sourceObject: sampleEpisode1
    )
    
    // When
    index.addDocument(document)
    
    // Then
    XCTAssertEqual(index.findDocuments(for: "swift").count, 1)
    XCTAssertEqual(index.findDocuments(for: "programming").count, 1)
    XCTAssertEqual(index.findDocuments(for: "tutorial").count, 1)
  }
  
  func test_searchIndex_clearRemovesAllDocuments() {
    // Given
    let index = SearchIndex()
    let document = SearchableDocument(
      id: "test-doc",
      type: .podcast,
      fields: [.title: "Swift Programming"],
      sourceObject: samplePodcast1
    )
    
    // When
    index.addDocument(document)
    index.clear()
    
    // Then
    XCTAssertTrue(index.findDocuments(for: "swift").isEmpty)
  }
  
  // MARK: - SearchService Tests
  
  @MainActor
  func test_searchService_basicSearch() async {
    // Given
    let podcastSource = MockPodcastIndexSource(podcasts: [samplePodcast1, samplePodcast2])
    let episodeSource = MockEpisodeIndexSource(episodes: [sampleEpisode1])
    let searchService = SearchService(indexSources: [podcastSource, episodeSource])
    
    await searchService.rebuildIndex()
    
    // When
    let results = await searchService.search(query: "swift", filter: nil)
    
    // Then
    XCTAssertFalse(results.isEmpty)
    
    // Check that swift-related content is returned
    let hasSwiftPodcast = results.contains { result in
      if case .podcast(let podcast, _) = result {
        return podcast.id == "tech-podcast"
      }
      return false
    }
    
    let hasSwiftEpisode = results.contains { result in
      if case .episode(let episode, _) = result {
        return episode.id == "ep-swift-intro"
      }
      return false
    }
    
    XCTAssertTrue(hasSwiftPodcast)
    XCTAssertTrue(hasSwiftEpisode)
  }
  
  @MainActor
  func test_searchService_podcastOnlyFilter() async {
    // Given
    let podcastSource = MockPodcastIndexSource(podcasts: [samplePodcast1])
    let episodeSource = MockEpisodeIndexSource(episodes: [sampleEpisode1])
    let searchService = SearchService(indexSources: [podcastSource, episodeSource])
    
    await searchService.rebuildIndex()
    
    // When
    let results = await searchService.search(query: "swift", filter: .podcastsOnly)
    
    // Then
    XCTAssertFalse(results.isEmpty)
    
    // Check that only podcasts are returned
    let allArePodcasts = results.allSatisfy { result in
      if case .podcast(_, _) = result { return true }
      return false
    }
    
    XCTAssertTrue(allArePodcasts)
  }
  
  @MainActor
  func test_searchService_episodeOnlyFilter() async {
    // Given
    let podcastSource = MockPodcastIndexSource(podcasts: [samplePodcast1])
    let episodeSource = MockEpisodeIndexSource(episodes: [sampleEpisode1])
    let searchService = SearchService(indexSources: [podcastSource, episodeSource])
    
    await searchService.rebuildIndex()
    
    // When
    let results = await searchService.search(query: "swift", filter: .episodesOnly)
    
    // Then
    XCTAssertFalse(results.isEmpty)
    
    // Check that only episodes are returned
    let allAreEpisodes = results.allSatisfy { result in
      if case .episode(_, _) = result { return true }
      return false
    }
    
    XCTAssertTrue(allAreEpisodes)
  }
  
  @MainActor
  func test_searchService_rankingOrderByRelevance() async {
    // Given
    let podcastSource = MockPodcastIndexSource(podcasts: [samplePodcast1, samplePodcast2])
    let episodeSource = MockEpisodeIndexSource(episodes: [sampleEpisode1, sampleEpisode3])
    let searchService = SearchService(indexSources: [podcastSource, episodeSource])
    
    await searchService.rebuildIndex()
    
    // When: Search for "swift" which appears in title and description
    let results = await searchService.search(query: "swift", filter: nil)
    
    // Then: Results should be ordered by relevance score
    XCTAssertGreaterThan(results.count, 1)
    
    // Verify descending order of relevance scores
    for i in 0..<(results.count - 1) {
      let currentScore = results[i].relevanceScore
      let nextScore = results[i + 1].relevanceScore
      XCTAssertGreaterThanOrEqual(currentScore, nextScore,
        "Results should be ordered by relevance score (descending)")
    }
  }
  
  @MainActor
  func test_searchService_titleWeightedHigherThanDescription() async {
    // Given: One item with "swift" in title, another with "swift" in description
    let titlePodcast = Podcast(
      id: "title-match",
      title: "Swift Mastery",
      author: "Author",
      description: "Learn programming",
      feedURL: URL(string: "https://example.com/title.xml")!
    )
    
    let descriptionPodcast = Podcast(
      id: "description-match",
      title: "Programming Guide",
      author: "Author",
      description: "Everything about Swift development",
      feedURL: URL(string: "https://example.com/desc.xml")!
    )
    
    let podcastSource = MockPodcastIndexSource(podcasts: [titlePodcast, descriptionPodcast])
    let searchService = SearchService(indexSources: [podcastSource])
    
    await searchService.rebuildIndex()
    
    // When
    let results = await searchService.search(query: "swift", filter: nil)
    
    // Then: Title match should rank higher than description match
    XCTAssertGreaterThanOrEqual(results.count, 2)
    
    if case .podcast(let topResult, _) = results.first {
      XCTAssertEqual(topResult.id, "title-match",
        "Podcast with 'swift' in title should rank higher than description match")
    } else {
      XCTFail("Expected podcast result")
    }
  }
  
  @MainActor
  func test_searchService_emptyQueryReturnsEmptyResults() async {
    // Given
    let podcastSource = MockPodcastIndexSource(podcasts: [samplePodcast1])
    let searchService = SearchService(indexSources: [podcastSource])
    
    await searchService.rebuildIndex()
    
    // When
    let results = await searchService.search(query: "", filter: nil)
    
    // Then
    XCTAssertTrue(results.isEmpty)
  }
  
  @MainActor
  func test_searchService_noMatchesReturnsEmptyResults() async {
    // Given
    let podcastSource = MockPodcastIndexSource(podcasts: [samplePodcast1])
    let searchService = SearchService(indexSources: [podcastSource])
    
    await searchService.rebuildIndex()
    
    // When
    let results = await searchService.search(query: "xyz123", filter: nil)
    
    // Then
    XCTAssertTrue(results.isEmpty)
  }
  
  @MainActor
  func test_searchService_caseInsensitiveSearch() async {
    // Given
    let podcastSource = MockPodcastIndexSource(podcasts: [samplePodcast1])
    let searchService = SearchService(indexSources: [podcastSource])
    
    await searchService.rebuildIndex()
    
    // When: Search with different cases
    let lowerResults = await searchService.search(query: "swift", filter: nil)
    let upperResults = await searchService.search(query: "SWIFT", filter: nil)
    let mixedResults = await searchService.search(query: "Swift", filter: nil)
    
    // Then: All should return same results
    XCTAssertEqual(lowerResults.count, upperResults.count)
    XCTAssertEqual(lowerResults.count, mixedResults.count)
    XCTAssertFalse(lowerResults.isEmpty)
  }
  
  @MainActor
  func test_searchService_multiTermQuery() async {
    // Given
    let podcastSource = MockPodcastIndexSource(podcasts: [samplePodcast1, samplePodcast2])
    let episodeSource = MockEpisodeIndexSource(episodes: [sampleEpisode1, sampleEpisode3])
    let searchService = SearchService(indexSources: [podcastSource, episodeSource])
    
    await searchService.rebuildIndex()
    
    // When: Search for multiple terms
    let results = await searchService.search(query: "swift programming", filter: nil)
    
    // Then: Items containing both terms should rank higher
    XCTAssertFalse(results.isEmpty)
    
    // Verify that results containing both terms exist
    let hasBothTerms = results.contains { result in
      switch result {
      case .podcast(let podcast, _):
        let text = "\(podcast.title) \(podcast.description ?? "")".lowercased()
        return text.contains("swift") && text.contains("programming")
      case .episode(let episode, _):
        let text = "\(episode.title) \(episode.description ?? "")".lowercased()
        return text.contains("swift") && text.contains("programming")
      case .note(_, _):
        return false
      }
    }
    
    XCTAssertTrue(hasBothTerms)
  }
}

// MARK: - SearchResult Helper Extension

extension SearchResult {
  var relevanceScore: Double {
    switch self {
    case .podcast(_, let score):
      return score
    case .episode(_, let score):
      return score
    case .note(_, let score):
      return score
    }
  }
}
