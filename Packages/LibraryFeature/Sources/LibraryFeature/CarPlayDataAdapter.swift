import CoreModels
import Foundation

/// Represents a podcast entry suitable for CarPlay rendering.
struct CarPlayPodcastItem: Equatable {
  let podcast: Podcast
  let title: String
  let detailText: String
  let voiceCommands: [String]
  let episodes: [CarPlayEpisodeItem]
}

/// Represents an episode entry suitable for CarPlay rendering.
struct CarPlayEpisodeItem: Equatable {
  let episode: Episode
  let title: String
  let detailText: String
  let voiceCommands: [String]
  let isInProgress: Bool
  let isPlayed: Bool
}

enum CarPlayDataAdapter {
  /// Maximum number of episodes to expose per podcast in CarPlay (per HIG guidance).
  private static let maximumEpisodes = 100

  static func makePodcastItems(from podcasts: [Podcast]) -> [CarPlayPodcastItem] {
    podcasts
      .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
      .map { podcast in
        let episodes = makeEpisodeItems(for: podcast)
        let episodeCount = episodes.count
        let detail = episodeCount == 1 ? "1 episode" : "\(episodeCount) episodes"

        let commands = [
          podcast.title,
          "Play \(podcast.title)",
          "Play latest from \(podcast.title)"
        ]

        return CarPlayPodcastItem(
          podcast: podcast,
          title: podcast.title,
          detailText: detail,
          voiceCommands: commands,
          episodes: episodes
        )
      }
  }

  static func makeEpisodeItems(for podcast: Podcast) -> [CarPlayEpisodeItem] {
    let sorted = podcast.episodes.sorted(by: newestFirst)
    return sorted.prefix(maximumEpisodes).map { episode in
      let detail = makeDetailText(for: episode)
      let commands = makeVoiceCommands(for: episode, podcastTitle: podcast.title)
      return CarPlayEpisodeItem(
        episode: episode,
        title: episode.title,
        detailText: detail,
        voiceCommands: commands,
        isInProgress: episode.isInProgress,
        isPlayed: episode.isPlayed
      )
    }
  }

  private static func newestFirst(lhs: Episode, rhs: Episode) -> Bool {
    switch (lhs.pubDate, rhs.pubDate) {
    case let (leftDate?, rightDate?):
      return leftDate > rightDate
    case (.some, .none):
      return true
    case (.none, .some):
      return false
    case (.none, .none):
      return lhs.dateAdded > rhs.dateAdded
    }
  }

  private static func makeDetailText(for episode: Episode) -> String {
    var components: [String] = []

    if let duration = episode.duration {
      components.append(format(duration: duration))
    }

    if episode.isInProgress {
      components.append("In Progress")
    } else if episode.isPlayed {
      components.append("Played")
    }

    return components.joined(separator: " • ")
  }

  private static func makeVoiceCommands(for episode: Episode, podcastTitle: String) -> [String] {
    var commands: [String] = []
    commands.append(episode.title)
    commands.append("Play \(episode.title)")
    if !podcastTitle.isEmpty {
      commands.append("Play \(episode.title) from \(podcastTitle)")
      commands.append("Add \(episode.title) from \(podcastTitle) to queue")
    }
    return commands
  }

  private static func format(duration: TimeInterval) -> String {
    let totalSeconds = Int(duration)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60

    if hours > 0 {
      return "\(hours)h \(minutes)m"
    } else {
      return "\(minutes)m"
    }
  }
}
