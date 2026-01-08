//
//  MiniPlayerView.swift
//  PlayerFeature
//
//  Created for Issue 03.1.1.1: Mini-Player Foundation
//

import CoreModels
import SharedUtilities
import SwiftUI

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

    ZStack(alignment: .top) {
      Group {
        if state.isVisible, let episode = state.episode {
          // Issue 03.3.4.2: Unified card layout with conditional content
          miniPlayerCard(for: episode, state: state)
        }
      }
      .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.isVisible)

      if let alert = viewModel.playbackAlert {
        PlaybackAlertToastView(
          alert: alert,
          onPrimary: viewModel.performPrimaryAlertAction,
          onSecondary: viewModel.performSecondaryAlertAction,
          onDismiss: viewModel.dismissAlert
        )
        .padding(.horizontal, 16)
        .padding(.top, -8)
      }
    }
  }

  // MARK: - Subviews ---------------------------------------------------------

  /// Issue 03.3.4.2: Unified mini-player card with conditional content
  @ViewBuilder
  private func miniPlayerCard(for episode: Episode, state: MiniPlayerDisplayState) -> some View {
    HStack(spacing: 12) {
      artwork(for: episode)

      VStack(alignment: .leading, spacing: 4) {
        Text(episode.title)
          .font(.subheadline)
          .fontWeight(.semibold)
          .lineLimit(1)
          .accessibilityIdentifier("Mini Player Episode Title")

        // Show error overlay if present, otherwise show podcast subtitle
        if let error = state.error {
          errorContent(for: error)
        } else if !episode.podcastTitle.isEmpty {
          Text(episode.podcastTitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityIdentifier("Mini Player Podcast Title")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Show transport controls only when no error
      if state.error == nil {
        transportControls(state: state)
      }
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
      onTapExpand()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityIdentifier("Mini Player")
    .accessibilityLabel(miniPlayerAccessibilityLabel(for: episode, error: state.error))
    .accessibilityHint("Double-tap to open the full player")
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  private func miniPlayerAccessibilityLabel(
    for episode: Episode,
    error: PlaybackError?
  ) -> String {
    guard let error = error else {
      return "Mini player showing \(episode.title). Double-tap to open the full player."
    }

    let recoverableHint = error.isRecoverable ? " Retry playback is available." : ""
    return "Mini player showing \(episode.title) with error: \(error.userMessage).\(recoverableHint)"
  }

  /// Issue 03.3.4.2: Error content for failed playback
  private func errorContent(for error: PlaybackError) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.red)
        .font(.caption)
        .accessibilityHidden(true)

      Text(error.userMessage)
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
        .accessibilityIdentifier("MiniPlayer.ErrorMessage")

      if error.isRecoverable {
        Button {
          viewModel.retryPlayback()
        } label: {
          Text("Retry")
            .font(.caption.bold())
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("MiniPlayer.RetryButton")
        .accessibilityLabel("Retry playback")
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.background.opacity(0.95))
    .cornerRadius(8)
    .accessibilityIdentifier("MiniPlayer.ErrorOverlay")
  }

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
  MiniPlayerPreview()
}

private struct MiniPlayerPreview: View {
  @StateObject private var viewModel: MiniPlayerViewModel

  init() {
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
    stubPlayer.play(episode: episode, duration: episode.duration)

    let presenter = PlaybackAlertPresenter()
    let miniViewModel = MiniPlayerViewModel(
      playbackService: stubPlayer,
      alertPresenter: presenter
    )

    _viewModel = StateObject(wrappedValue: miniViewModel)
  }

  var body: some View {
    VStack {
      Spacer()

      MiniPlayerView(viewModel: viewModel) {
        print("Expand tapped")
      }
      .padding(.bottom, 24)
    }
  }
}
#endif
