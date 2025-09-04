import SwiftUI
import CoreModels

/// View component for displaying individual search results
public struct SearchResultView: View {
    let searchResult: SearchResult
    let onSubscribe: (Podcast) -> Void
    
    public init(searchResult: SearchResult, onSubscribe: @escaping (Podcast) -> Void) {
        self.searchResult = searchResult
        self.onSubscribe = onSubscribe
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Artwork
            AsyncImage(url: artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                
                // Author/Creator
                if let author = author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Description
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // Type indicator and relevance
                HStack {
                    Label(resultTypeLabel, systemImage: resultTypeIcon)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    if case let .podcast(podcast, _) = searchResult, !podcast.isSubscribed {
                        Button(action: {
                            onSubscribe(podcast)
                        }) {
                            Label("Subscribe", systemImage: "plus.circle.fill")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Subscribe to \(podcast.title)")
                    } else if case let .podcast(_, _) = searchResult {
                        Label("Subscribed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .accessibilityLabel("Already subscribed")
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Computed Properties
    
    private var artworkURL: URL? {
        switch searchResult {
        case .podcast(let podcast, _):
            return podcast.artworkURL
        case .episode(_, _):
            // Episodes don't have their own artwork URL in the current model
            return nil
        case .note(_, _):
            return nil
        }
    }
    
    private var title: String {
        switch searchResult {
        case .podcast(let podcast, _):
            return podcast.title
        case .episode(let episode, _):
            return episode.title
        case .note(let note, _):
            return "Note: \(note.content.prefix(50))..."
        }
    }
    
    private var author: String? {
        switch searchResult {
        case .podcast(let podcast, _):
            return podcast.author
        case .episode(let episode, _):
            // Episode model only has podcastID, not podcastTitle
            // Using podcastID as a fallback, or could be enhanced later to resolve the actual title
            return episode.podcastID
        case .note(_, _):
            return nil
        }
    }
    
    private var description: String? {
        switch searchResult {
        case .podcast(let podcast, _):
            return podcast.description
        case .episode(let episode, _):
            return episode.description
        case .note(let note, _):
            return note.content
        }
    }
    
    private var resultTypeLabel: String {
        switch searchResult {
        case .podcast(_, _):
            return "Podcast"
        case .episode(_, _):
            return "Episode"
        case .note(_, _):
            return "Note"
        }
    }
    
    private var resultTypeIcon: String {
        switch searchResult {
        case .podcast(_, _):
            return "mic.fill"
        case .episode(_, _):
            return "play.circle.fill"
        case .note(_, _):
            return "note.text"
        }
    }
}

#if DEBUG
struct SearchResultView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SearchResultView(
                searchResult: .podcast(
                    Podcast(
                        id: "test-podcast",
                        title: "Swift Talk",
                        author: "objc.io",
                        description: "A weekly video series on Swift programming.",
                        feedURL: URL(string: "https://example.com/feed")!,
                        isSubscribed: false
                    ),
                    relevanceScore: 0.95
                ),
                onSubscribe: { _ in }
            )
            
            SearchResultView(
                searchResult: .episode(
                    Episode(
                        id: "test-episode",
                        title: "Understanding Actors in Swift",
                        podcastID: "test-podcast",
                        playbackPosition: 0,
                        isPlayed: false,
                        pubDate: Date(),
                        duration: 1800,
                        description: "Deep dive into Swift's actor model for concurrency."
                    ),
                    relevanceScore: 0.87
                ),
                onSubscribe: { _ in }
            )
        }
        .padding()
    }
}
#endif