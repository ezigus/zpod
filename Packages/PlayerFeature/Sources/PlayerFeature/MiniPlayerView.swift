//
//  MiniPlayerView.swift
//  PlayerFeature
//
//  Created for Issue 03.1.1.1: Mini-Player Foundation
//

import CoreModels
import SwiftUI

/// Compact mini-player bar that appears during playback
public struct MiniPlayerView: View {
  @ObservedObject private var viewModel: MiniPlayerViewModel
  private let onTapExpand: () -> Void
  
  public init(viewModel: MiniPlayerViewModel, onTapExpand: @escaping () -> Void) {
    self.viewModel = viewModel
    self.onTapExpand = onTapExpand
  }
  
  public var body: some View {
    if viewModel.isVisible, let episode = viewModel.currentEpisode {
      HStack(spacing: 12) {
        // Episode artwork thumbnail
        artworkThumbnail
        
        // Episode and podcast titles
        VStack(alignment: .leading, spacing: 4) {
          Text(episode.title)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(1)
            .accessibilityIdentifier("Mini Player Episode Title")
          
          if !episode.podcastTitle.isEmpty {
            Text(episode.podcastTitle)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .accessibilityIdentifier("Mini Player Podcast Title")
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        Spacer()
        
        // Transport controls
        HStack(spacing: 16) {
          skipBackwardButton
          playPauseButton
          skipForwardButton
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color(.systemBackground))
      .overlay(
        Rectangle()
          .fill(Color(.separator))
          .frame(height: 0.5),
        alignment: .top
      )
      .contentShape(Rectangle())
      .onTapGesture {
        onTapExpand()
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("Mini Player")
      .accessibilityLabel("Mini Player")
    }
  }
  
  // MARK: - Subviews
  
  private var artworkThumbnail: some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(Color.gray.opacity(0.3))
      .frame(width: 48, height: 48)
      .overlay(
        Image(systemName: "music.note")
          .font(.title3)
          .foregroundColor(.gray)
      )
      .accessibilityHidden(true)
  }
  
  private var skipBackwardButton: some View {
    Button {
      viewModel.skipBackward()
    } label: {
      Image(systemName: "gobackward.15")
        .font(.title3)
        .foregroundColor(.primary)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel("Skip Backward")
    .accessibilityHint("Skip backward 15 seconds")
    .accessibilityIdentifier("Mini Player Skip Backward")
  }
  
  private var playPauseButton: some View {
    Button {
      viewModel.togglePlayPause()
    } label: {
      Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
        .font(.title2)
        .foregroundColor(.primary)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
    .accessibilityHint("Toggles playback")
    .accessibilityIdentifier(viewModel.isPlaying ? "Mini Player Pause" : "Mini Player Play")
  }
  
  private var skipForwardButton: some View {
    Button {
      viewModel.skipForward()
    } label: {
      Image(systemName: "goforward.30")
        .font(.title3)
        .foregroundColor(.primary)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel("Skip Forward")
    .accessibilityHint("Skip forward 30 seconds")
    .accessibilityIdentifier("Mini Player Skip Forward")
  }
}

// MARK: - Preview

#if DEBUG
import PlaybackEngine

#Preview {
  VStack {
    Spacer()
    
    let stubPlayer = StubEpisodePlayer(
      initialEpisode: Episode(
        id: "preview-1",
        title: "Understanding Swift Concurrency",
        podcastID: "podcast-1",
        playbackPosition: 0,
        isPlayed: false,
        pubDate: Date(),
        duration: 3600,
        description: "A deep dive into Swift concurrency",
        audioURL: URL(string: "https://example.com/episode.mp3"),
        podcastTitle: "Swift Talk"
      ),
      ticker: TimerTicker()
    )
    
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    MiniPlayerView(viewModel: viewModel) {
      print("Expand tapped")
    }
  }
}
#endif
