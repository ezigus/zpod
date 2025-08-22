import Foundation
import CoreModels

/// Search index source for podcasts from a PodcastManager
public final class PodcastIndexSource: SearchIndexSource {
  private let podcastManager: PodcastManaging
  
  public init(podcastManager: PodcastManaging) {
    self.podcastManager = podcastManager
  }
  
  public func documents() -> [SearchableDocument] {
    return podcastManager.all().map { podcast in
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

/// Search index source for episodes from podcasts
public final class EpisodeIndexSource: SearchIndexSource {
  private let podcastManager: PodcastManaging
  
  public init(podcastManager: PodcastManaging) {
    self.podcastManager = podcastManager
  }
  
  public func documents() -> [SearchableDocument] {
    var episodes: [Episode] = []
    
    // Collect all episodes from all podcasts
    for podcast in podcastManager.all() {
      episodes.append(contentsOf: podcast.episodes)
    }
    
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

/// Future: Search index source for notes
public final class NoteIndexSource: SearchIndexSource {
  private let notes: [Note]
  
  public init(notes: [Note] = []) {
    self.notes = notes
  }
  
  public func documents() -> [SearchableDocument] {
    return notes.map { note in
      SearchableDocument(
        id: note.id,
        type: .note,
        fields: [
          .description: note.content // Using description field for note content
        ],
        sourceObject: note
      )
    }
  }
}