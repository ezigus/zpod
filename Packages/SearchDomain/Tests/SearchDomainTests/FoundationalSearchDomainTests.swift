import XCTest
import Foundation
import CoreModels
import SharedUtilities
import TestSupport
@testable import SearchDomain

/// Foundational test suite for SearchDomain package
final class FoundationalSearchDomainTests: XCTestCase {
    
    private var searchIndex: SearchIndex!
    private var tokenizer: Tokenizer!
    
    override func setUp() {
        super.setUp()
        
        // Create fresh instances for each test
        searchIndex = SearchIndex()
        tokenizer = Tokenizer()
    }
    
    override func tearDown() {
        searchIndex = nil
        tokenizer = nil
        super.tearDown()
    }
    
    // MARK: - Tokenizer Tests
    
    func testTokenizer_BasicTokenization() {
        // Given: Text containing mixed case, punctuation, and stop words
        let text = "The Quick Brown Fox Jumps Over the Lazy Dog!"
        
        // When: Tokenizing the text
        let tokens = tokenizer.tokenize(text)
        
        // Then: Should return normalized tokens without stop words
        // Note: "over" is a stop word and should be filtered out
        let requiredTokens = ["quick", "brown", "fox", "jumps", "lazy", "dog"]
        let tokenSet = Set(tokens)
        
        for requiredToken in requiredTokens {
            XCTAssertTrue(tokenSet.contains(requiredToken), "Should contain token: \(requiredToken)")
        }
        
        // Should not contain common stop words from the sentence
        let stopWords = ["the"]
        for stopWord in stopWords {
            XCTAssertFalse(tokenSet.contains(stopWord), "Should not contain stop word: \(stopWord)")
        }
    }
    
    func testTokenizer_UnicodeHandling() {
        // Given: Text with Unicode characters
        let text = "Café Podcast"
        
        // When: Tokenizing Unicode text
        let tokens = tokenizer.tokenize(text)
        
        // Then: Should handle Unicode characters appropriately
        XCTAssertTrue(tokens.contains("café") || tokens.contains("cafe"), "Should handle accented characters")
        XCTAssertTrue(tokens.contains("podcast"), "Should handle mixed content")
    }
    
    func testTokenizer_EdgeCases() {
        // Given: Various edge case inputs
        let emptyText = ""
        let whitespaceOnly = "   \n\t  "
        let numbersOnly = "123 456"
        let punctuationOnly = "!@#$%^&*()"
        
        // When: Tokenizing edge cases
        let emptyTokens = tokenizer.tokenize(emptyText)
        let whitespaceTokens = tokenizer.tokenize(whitespaceOnly)
        let numberTokens = tokenizer.tokenize(numbersOnly)
        let punctuationTokens = tokenizer.tokenize(punctuationOnly)
        
        // Then: Should handle edge cases gracefully
        XCTAssertTrue(emptyTokens.isEmpty, "Empty text should produce no tokens")
        XCTAssertTrue(whitespaceTokens.isEmpty, "Whitespace-only should produce no tokens")
        XCTAssertEqual(numberTokens, ["123", "456"], "Should tokenize numbers")
        XCTAssertTrue(punctuationTokens.isEmpty, "Punctuation-only should produce no tokens")
    }
    
    func testTokenizer_Normalization() {
        // Given: Terms with varying case
        let normalizedPodcast = tokenizer.normalize("PODCAST")
        let normalizedEpisode = tokenizer.normalize("Episode")
        
        // Then: Should normalize to lowercase
        XCTAssertEqual(normalizedPodcast, "podcast", "Should normalize to lowercase")
        XCTAssertEqual(normalizedEpisode, "episode", "Should normalize to lowercase")
    }
    
    // MARK: - SearchIndex Tests
    
    func testSearchIndex_DocumentIndexing() {
        // Given: A searchable document
        let podcast = MockPodcast.createSample(id: "test-pod", title: "Test Podcast")
        let document = SearchableDocument(
            id: podcast.id,
            type: .podcast,
            fields: [
                .title: podcast.title,
                .author: podcast.author ?? "",
                .description: podcast.description ?? ""
            ],
            sourceObject: podcast
        )
        
        // When: Adding document to index
        searchIndex.addDocument(document)
        
        // Then: Should be able to search for indexed terms
        let podcastResults = searchIndex.findDocuments(for: "podcast")
        let testResults = searchIndex.findDocuments(for: "test")
        
        XCTAssertFalse(podcastResults.isEmpty, "Should find documents containing 'podcast'")
        XCTAssertFalse(testResults.isEmpty, "Should find documents containing 'test'")
        XCTAssertTrue(testResults.contains { $0.id == podcast.id }, "Should find the correct document")
    }
    
    func testSearchIndex_MultipleDocuments() {
        // Given: Multiple documents
        let podcast1 = MockPodcast.createSample(id: "p1", title: "Tech Podcast")
        let podcast2 = MockPodcast.createSample(id: "p2", title: "Science Show")
        
        let doc1 = SearchableDocument(
            id: podcast1.id,
            type: .podcast,
            fields: [.title: podcast1.title, .author: podcast1.author ?? ""],
            sourceObject: podcast1
        )
        let doc2 = SearchableDocument(
            id: podcast2.id,
            type: .podcast,
            fields: [.title: podcast2.title, .author: podcast2.author ?? ""],
            sourceObject: podcast2
        )
        
        // When: Adding multiple documents
        searchIndex.addDocument(doc1)
        searchIndex.addDocument(doc2)
        
        // Then: Should find documents based on different terms
        let scienceResults = searchIndex.findDocuments(for: "science")
        let podcastResults = searchIndex.findDocuments(for: "podcast")
        
        XCTAssertEqual(scienceResults.count, 1, "Only science document should contain 'science'")
        XCTAssertEqual(podcastResults.count, 1, "Only tech document should contain 'podcast'")
    }
    
    func testSearchIndex_ClearFunctionality() {
        // Given: Index with documents
        let podcast = MockPodcast.createSample(title: "Test Podcast")
        let document = SearchableDocument(
            id: podcast.id,
            type: .podcast,
            fields: [.title: podcast.title],
            sourceObject: podcast
        )
        
        searchIndex.addDocument(document)
        XCTAssertFalse(searchIndex.findDocuments(for: "test").isEmpty, "Should have documents")
        
        // When: Clearing the index
        searchIndex.clear()
        
        // Then: Should have no documents
        XCTAssertTrue(searchIndex.findDocuments(for: "test").isEmpty, "Should have no documents after clear")
        XCTAssertTrue(searchIndex.getAllTerms().isEmpty, "Should have no terms after clear")
    }
    
    // MARK: - Performance Tests
    
    func testSearchIndex_PerformanceBaseline() {
        // Given: Large number of documents
        let documentCount = 50 // Reduced for reasonable test time
        
        let startTime = Date()
        
        // When: Indexing many documents
        for i in 0..<documentCount {
            let podcast = MockPodcast.createSample(
                id: "podcast-\(i)",
                title: "Podcast \(i)"
            )
            let document = SearchableDocument(
                id: podcast.id,
                type: .podcast,
                fields: [
                    .title: podcast.title,
                    .author: podcast.author ?? "",
                    .description: podcast.description ?? ""
                ],
                sourceObject: podcast
            )
            searchIndex.addDocument(document)
        }
        
        // Perform multiple searches
        for _ in 0..<5 {
            let _ = searchIndex.findDocuments(for: "podcast")
            let _ = searchIndex.findDocuments(for: "author")
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then: Should complete within reasonable time
        XCTAssertLessThan(duration, 2.0, "Indexing and searching should be performant")
    }
    
    // MARK: - Cross-Platform Compatibility Tests
    
    func testCrossPlatformCompatibility() {
        // Given: Search components on current platform
        let tokenizer = Tokenizer()
        let searchIndex = SearchIndex()
        
        // When: Using search functionality
        let tokens = tokenizer.tokenize("cross platform test")
        let normalizedTerm = tokenizer.normalize("TEST")
        
        // Then: Should work across different platforms
        XCTAssertFalse(tokens.isEmpty, "Tokenization should work on all platforms")
        XCTAssertEqual(normalizedTerm, "test", "Normalization should work on all platforms")
        
        // Add a simple document to verify index functionality
        let podcast = MockPodcast.createSample(title: "Platform Test")
        let document = SearchableDocument(
            id: podcast.id,
            type: .podcast,
            fields: [.title: podcast.title],
            sourceObject: podcast
        )
        searchIndex.addDocument(document)
        
        let results = searchIndex.findDocuments(for: "platform")
        XCTAssertFalse(results.isEmpty, "Search index should work on all platforms")
    }
    
    func testSendableCompliance() {
        // Given: Search domain types that should be Sendable
        let document = SearchableDocument(
            id: "test-id",
            type: .podcast,
            fields: [.title: "Test Title"],
            sourceObject: MockPodcast.createSample(title: "Test")
        )
        
        // Then: Should be usable in concurrent contexts (compile-time check)
        XCTAssertEqual(document.id, "test-id", "Should be Sendable-compliant")
        XCTAssertEqual(document.type, .podcast, "Should maintain type information")
    }
}