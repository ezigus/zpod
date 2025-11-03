//
//  MiniPlayerView.swift
//  PlayerFeature
//
//  Created for Issue 03.1.1.1: Mini-Player Foundation
//

import CoreModels
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// Compact mini-player bar that appears during playback.
public struct MiniPlayerView: View {
  @ObservedObject private var viewModel: MiniPlayerViewModel
  private let onTapExpand: () -> Void

  public init(viewModel: MiniPlayerViewModel, onTapExpand: @escaping () -> Void) {
    self.viewModel = viewModel
    self.onTapExpand = onTapExpand
  }

  public var body: some View {
    let state = viewModel.displayState

    Group {
      if state.isVisible, let episode = state.episode {
        HStack(spacing: 12) {
          artwork(for: episode)

          VStack(alignment: .leading, spacing: 4) {
            Text(episode.title)
              .font(.subheadline)
              .fontWeight(.semibold)
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

          transportControls(state: state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 4, y: 2)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onTapGesture {
          performHaptic()
          onTapExpand()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Mini Player")
        .accessibilityLabel("Mini player showing \(episode.title)")
        .accessibilityHint("Double-tap to open the full player")
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.isVisible)
  }

  // MARK: - Subviews ---------------------------------------------------------

  @ViewBuilder
  private func artwork(for episode: Episode) -> some View {
    AsyncImage(url: episode.artworkURL) { phase in
      switch phase {
      case .empty:
        placeholderArtwork
      case .success(let image):
        image
          .resizable()
          .scaledToFill()
          .frame(width: 52, height: 52)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .transition(.opacity)
      case .failure:
        placeholderArtwork
      @unknown default:
        placeholderArtwork
      }
    }
    .frame(width: 52, height: 52)
    .accessibilityHidden(true)
  }

  private var placeholderArtwork: some View {
    RoundedRectangle(cornerRadius: 10)
      .fill(Color.gray.opacity(0.25))
      .overlay(
        Image(systemName: "mic.fill")
          .font(.title3)
          .foregroundStyle(.secondary)
      )
  }

  @ViewBuilder
  private func transportControls(state: MiniPlayerDisplayState) -> some View {
    HStack(spacing: 12) {
      Button {
        performHaptic()
        viewModel.skipBackward()
      } label: {
        Image(systemName: "gobackward.15")
          .font(.title3)
      }
      .buttonStyle(PressableButtonStyle())
      .accessibilityLabel("Skip backward")
      .accessibilityHint("Jumps back fifteen seconds")
      .accessibilityIdentifier("Mini Player Skip Backward")

      Button {
        performHaptic()
        viewModel.togglePlayPause()
      } label: {
        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
          .font(.title2)
      }
      .buttonStyle(PressableButtonStyle())
      .accessibilityLabel(state.isPlaying ? "Pause" : "Play")
      .accessibilityHint("Toggles playback")
      .accessibilityIdentifier(state.isPlaying ? "Mini Player Pause" : "Mini Player Play")

      Button {
        performHaptic()
        viewModel.skipForward()
      } label: {
        Image(systemName: "goforward.30")
          .font(.title3)
      }
      .buttonStyle(PressableButtonStyle())
      .accessibilityLabel("Skip forward")
      .accessibilityHint("Jumps ahead thirty seconds")
      .accessibilityIdentifier("Mini Player Skip Forward")
    }
    .foregroundStyle(.primary)
  }

  // MARK: - Helpers ----------------------------------------------------------

  private func performHaptic() {
    #if canImport(UIKit)
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #endif
  }

  private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .frame(width: 44, height: 44)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
        .opacity(configuration.isPressed ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
  }
}

// MARK: - Preview ------------------------------------------------------------

#if DEBUG
import PlaybackEngine

#Preview {
  let episode = Episode(
    id: "preview-1",
    title: "Understanding Swift Concurrency",
    podcastID: "podcast-1",
    podcastTitle: "Swift Talk",
    playbackPosition: 0,
    isPlayed: false,
    pubDate: Date(),
    duration: 3600,
    description: "A deep dive into Swift concurrency",
    audioURL: URL(string: "https://example.com/episode.mp3"),
    artworkURL: URL(string: "https://picsum.photos/200")
  )

  let stubPlayer = StubEpisodePlayer(initialEpisode: episode, ticker: TimerTicker())
  let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
  stubPlayer.play(episode: episode, duration: episode.duration)

  return VStack {
    Spacer()

    MiniPlayerView(viewModel: viewModel) {
      print("Expand tapped")
    }
    .padding(.bottom, 24)
  }
}
#endif
