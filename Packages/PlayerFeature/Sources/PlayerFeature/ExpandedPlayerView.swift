//
//  ExpandedPlayerView.swift
//  PlayerFeature
//
//  Created for Issue 03.1.1.2: Expanded Player Layout & Interaction
//

import CoreModels
import Foundation
import SharedUtilities
import SwiftUI

/// Full-screen player interface with large artwork, metadata, and comprehensive playback controls.
public struct ExpandedPlayerView: View {
  @ObservedObject private var viewModel: ExpandedPlayerViewModel
  @Environment(\.dismiss) private var dismiss

  public init(viewModel: ExpandedPlayerViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        // Background with gradient (always shown)
        gradientBackground
          .ignoresSafeArea()

        // Issue 03.3.4.3: Conditional content based on error state
        if let error = viewModel.currentError {
          errorView(error: error, geometry: geometry)
        } else {
          normalPlayerView(geometry: geometry)
        }

        // Overlays (debug, alerts) stay on top
        debugAndAlertOverlays(geometry: geometry)
      }
    }
  }

  // MARK: - Subviews

  private var gradientBackground: some View {
    LinearGradient(
      colors: [
        Color.black.opacity(0.95),
        Color.black.opacity(0.85),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  /// Issue 03.3.4.3: Error view for failed playback
  @ViewBuilder
  private func errorView(error: PlaybackError, geometry: GeometryProxy) -> some View {
    VStack(spacing: 0) {
      dragIndicator

      Spacer()

      VStack(spacing: 24) {
        // Large error icon
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 64))
          .foregroundColor(.red)
          .accessibilityHidden(true)

        // Error message
        VStack(spacing: 12) {
          Text("Playback Error")
            .font(.title2.bold())
            .foregroundColor(.white)

          Text(error.userMessage)
            .font(.body)
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
        }

        // Retry button (if recoverable)
        if error.isRecoverable {
          Button {
            viewModel.retryPlayback()
          } label: {
            Label("Retry Playback", systemImage: "arrow.clockwise")
              .font(.headline)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .tint(.white)
          .accessibilityIdentifier("ExpandedPlayer.RetryButton")
          .accessibilityLabel("Retry playback")
        }

        // Episode context
        if let episode = viewModel.episode {
          VStack(spacing: 6) {
            Text(episode.title)
              .font(.subheadline)
              .foregroundColor(.white.opacity(0.7))
              .lineLimit(2)
              .multilineTextAlignment(.center)

            Text(episode.podcastTitle)
              .font(.caption)
              .foregroundColor(.white.opacity(0.5))
              .lineLimit(1)
          }
          .padding(.top, 32)
        }
      }
      .padding(.horizontal, 32)

      Spacer()
    }
    .padding(.top, 8)
    .padding(.bottom, max(20, geometry.safeAreaInsets.bottom))
    .accessibilityElement(children: .ignore)
    .accessibilityIdentifier("ExpandedPlayer.ErrorView")
    .accessibilityLabel("Playback Error. \(error.userMessage)")
    .accessibilityHint(
      error.isRecoverable
        ? "Retry playback is available."
        : "Retry playback is not available for this error."
    )
  }

  /// Normal player view (non-error state)
  @ViewBuilder
  private func normalPlayerView(geometry: GeometryProxy) -> some View {
    VStack(spacing: 0) {
      // Drag indicator
      dragIndicator

      Spacer(minLength: 20)

      // Artwork
      artworkView(size: artworkSize(for: geometry))

      Spacer(minLength: 24)

      // Metadata
      metadataView
        .padding(.horizontal, 24)

      Spacer(minLength: 32)

      // Progress slider
      progressSliderView
        .padding(.horizontal, 24)

      Spacer(minLength: 32)

      // Transport controls
      transportControlsView
        .padding(.horizontal, 24)

      Spacer(minLength: 40)
    }
    .padding(.top, 8)
    .padding(.bottom, max(20, geometry.safeAreaInsets.bottom))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("Expanded Player")
  }

  /// Debug and alert overlays
  @ViewBuilder
  private func debugAndAlertOverlays(geometry: GeometryProxy) -> some View {
    if let debugText = viewModel.audioDebugText {
      audioDebugOverlay(text: debugText)
        .padding(.top, geometry.safeAreaInsets.top + 12)
        .padding(.horizontal, 16)
    }

    if let alert = viewModel.playbackAlert {
      PlaybackAlertToastView(
        alert: alert,
        onPrimary: viewModel.performPrimaryAlertAction,
        onSecondary: viewModel.performSecondaryAlertAction,
        onDismiss: viewModel.dismissAlert
      )
      .padding(.horizontal, 24)
      .padding(.top, geometry.safeAreaInsets.top + 16)
    }

    #if DEBUG
    // VoiceOver testing controls (Issue 03.3.4.3.1)
    if ProcessInfo.processInfo.environment["ENABLE_ERROR_DEBUG"] == "1" {
      VStack {
        Spacer()
        
        VStack(spacing: 12) {
          Text("Error Debug Controls")
            .font(.caption.bold())
            .foregroundColor(.white)
          
          HStack(spacing: 8) {
            Button("Network") {
              viewModel.debugTriggerNetworkError()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
            
            Button("Timeout") {
              viewModel.debugTriggerTimeoutError()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
          }
          
          HStack(spacing: 8) {
            Button("Stream") {
              viewModel.debugTriggerStreamFailedError()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.small)
            
            Button("Missing URL") {
              viewModel.debugTriggerMissingURLError()
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .controlSize(.small)
          }
          
          Button("Clear Error") {
            viewModel.debugClearError()
          }
          .buttonStyle(.bordered)
          .tint(.green)
          .controlSize(.small)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .padding(.bottom, 120)
      }
    }
    #endif
  }

  // MARK: - Player Components

  private var dragIndicator: some View {
    RoundedRectangle(cornerRadius: 2.5)
      .fill(Color.white.opacity(0.3))
      .frame(width: 36, height: 5)
      .accessibilityHidden(true)
  }

  private func audioDebugOverlay(text: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Audio Debug")
        .font(.caption)
        .fontWeight(.semibold)
      Text(text)
        .font(.caption2.monospaced())
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(8)
    .background(Color.black.opacity(0.6))
    .cornerRadius(8)
    .accessibilityIdentifier("Audio Debug Overlay")
    .accessibilityLabel(text)
  }

  @ViewBuilder
  private func artworkView(size: CGFloat) -> some View {
    if let episode = viewModel.episode {
      AsyncImage(url: episode.artworkURL) { phase in
        switch phase {
        case .empty:
          placeholderArtwork(size: size)
        case .success(let image):
          image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 20, y: 10)
            .transition(.opacity)
        case .failure:
          placeholderArtwork(size: size)
        @unknown default:
          placeholderArtwork(size: size)
        }
      }
      .frame(width: size, height: size)
      .accessibilityLabel("Episode artwork")
      .accessibilityHidden(true)
    } else {
      placeholderArtwork(size: size)
    }
  }

  private func placeholderArtwork(size: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .fill(Color.gray.opacity(0.3))
      .frame(width: size, height: size)
      .overlay(
        Image(systemName: "music.note")
          .font(.system(size: size * 0.3))
          .foregroundStyle(.white.opacity(0.6))
      )
      .shadow(radius: 20, y: 10)
  }

  private var metadataView: some View {
    VStack(spacing: 8) {
      if let episode = viewModel.episode {
        Text(episode.title)
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .accessibilityIdentifier("Expanded Player Episode Title")

        if !episode.podcastTitle.isEmpty {
          Text(episode.podcastTitle)
            .font(.body)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .accessibilityIdentifier("Expanded Player Podcast Title")
        }
      } else {
        Text("No Episode Playing")
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundStyle(.white.opacity(0.5))
      }
    }
  }

  private var progressSliderView: some View {
    VStack(spacing: 12) {
      GeometryReader { sliderGeometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.2))
            .frame(height: 4)

          RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: sliderGeometry.size.width * viewModel.progressFraction, height: 4)

          Circle()
            .fill(Color.white)
            .frame(width: 16, height: 16)
            .shadow(radius: 2)
            .offset(x: sliderGeometry.size.width * viewModel.progressFraction - 8)
        }
        .accessibilityHidden(true)
        .overlay {
          progressAccessibilitySlider
        }
      }
      .frame(height: 44)

      HStack {
        Text(viewModel.formattedCurrentTime)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.7))
          .monospacedDigit()
          .accessibilityHidden(true)

        Spacer()

        Text(viewModel.formattedDuration)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.7))
          .monospacedDigit()
          .accessibilityHidden(true)
      }
    }
  }

  @ViewBuilder
  private var progressAccessibilitySlider: some View {
    let upperBound = max(viewModel.duration, viewModel.currentPosition, 1)

    // Invisible system slider keeps accessibility and UI tests aligned with the custom scrubber UI.
    Slider(
      value: Binding(
        get: { viewModel.currentPosition },
        set: { newValue in
          let maxBound = max(viewModel.duration, viewModel.currentPosition, 1)
          let clampedPosition = min(max(newValue, 0), maxBound)
          if !viewModel.isScrubbing {
            viewModel.beginScrubbing()
          }
          viewModel.updateScrubbingPosition(clampedPosition)
        }
      ),
      in: 0...upperBound,
      onEditingChanged: { editing in
        if editing {
          performLightHaptic()
          viewModel.beginScrubbing()
        } else {
          performMediumHaptic()
          viewModel.endScrubbing()
        }
      }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .labelsHidden()
    .tint(.clear)
    // Keep the slider effectively invisible for users while allowing UI tests to interact reliably.
    .opacity(uiTestSliderOpacity)
    .accessibilityIdentifier("Progress Slider")
    .accessibilityLabel("Progress Slider")
    .accessibilityHint("Adjust playback position")
    .accessibilityValue(
      Text("\(viewModel.formattedCurrentTime) of \(viewModel.formattedDuration)")
    )
    .disabled(viewModel.episode == nil || viewModel.duration <= 0)
  }

  private var uiTestSliderOpacity: Double {
    if let rawValue = ProcessInfo.processInfo.environment["UITEST_SLIDER_OPACITY"],
      let value = Double(rawValue), value > 0
    {
      return value
    }
    return 0.01
  }

  private var transportControlsView: some View {
    HStack(spacing: 48) {
      // Skip backward
      Button {
        performLightHaptic()
        viewModel.skipBackward()
      } label: {
        Image(systemName: "gobackward.15")
          .font(.system(size: 32))
          .foregroundStyle(.white)
          .frame(width: 72, height: 72)
      }
      .buttonStyle(TransportButtonStyle())
      .accessibilityLabel("Skip backward 15 seconds")
      .accessibilityHint("Jumps back fifteen seconds")
      .accessibilityIdentifier("Expanded Player Skip Backward")

      // Play/Pause
      Button {
        performMediumHaptic()
        viewModel.togglePlayPause()
      } label: {
        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .font(.system(size: 80))
          .foregroundStyle(.white)
          .frame(width: 96, height: 96)
      }
      .buttonStyle(TransportButtonStyle())
      .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
      .accessibilityHint("Toggles playback")
      .accessibilityIdentifier(
        viewModel.isPlaying ? "Expanded Player Pause" : "Expanded Player Play")

      // Skip forward
      Button {
        performLightHaptic()
        viewModel.skipForward()
      } label: {
        Image(systemName: "goforward.30")
          .font(.system(size: 32))
          .foregroundStyle(.white)
          .frame(width: 72, height: 72)
      }
      .buttonStyle(TransportButtonStyle())
      .accessibilityLabel("Skip forward 30 seconds")
      .accessibilityHint("Jumps ahead thirty seconds")
      .accessibilityIdentifier("Expanded Player Skip Forward")
    }
  }

  // MARK: - Helpers

  private func artworkSize(for geometry: GeometryProxy) -> CGFloat {
    let screenWidth = geometry.size.width
    let screenHeight = geometry.size.height

    // Adjust size based on orientation and available space
    if screenHeight > screenWidth {
      // Portrait: use most of the width
      return min(screenWidth * 0.85, 400)
    } else {
      // Landscape: constrain to available height
      return min(screenHeight * 0.4, screenWidth * 0.4, 300)
    }
  }

  private func performLightHaptic() {
    HapticFeedbackService.shared.impact(.light)
  }

  private func performMediumHaptic() {
    HapticFeedbackService.shared.impact(.medium)
  }

  private struct TransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
        .opacity(configuration.isPressed ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
  }
}

// MARK: - Preview

#if DEBUG
  import PlaybackEngine

#Preview("Playing") {
  ExpandedPlayerPreview(isPaused: false)
}

#Preview("Paused") {
  ExpandedPlayerPreview(isPaused: true)
}

private struct ExpandedPlayerPreview: View {
  @StateObject private var viewModel: ExpandedPlayerViewModel

  init(isPaused: Bool) {
    let episode = isPaused ? ExpandedPlayerPreview.pausedEpisode : ExpandedPlayerPreview.playingEpisode
    let stubPlayer = StubEpisodePlayer(initialEpisode: episode, ticker: TimerTicker())
    stubPlayer.play(episode: episode, duration: episode.duration)
    if isPaused {
      stubPlayer.pause()
    }

    let presenter = PlaybackAlertPresenter()
    let previewViewModel = ExpandedPlayerViewModel(
      playbackService: stubPlayer,
      alertPresenter: presenter
    )
    _viewModel = StateObject(wrappedValue: previewViewModel)
  }

  var body: some View {
    ExpandedPlayerView(viewModel: viewModel)
      .preferredColorScheme(.dark)
  }

  private static var playingEpisode: Episode {
    Episode(
      id: "preview-1",
      title: "Understanding Swift Concurrency and Modern Async Patterns",
      podcastID: "podcast-1",
      podcastTitle: "Swift Talk",
      playbackPosition: 1200,
      isPlayed: false,
      pubDate: Date(),
      duration: 3600,
      description: "A deep dive into Swift concurrency",
      audioURL: URL(string: "https://example.com/episode.mp3"),
      artworkURL: URL(string: "https://picsum.photos/400")
    )
  }

  private static var pausedEpisode: Episode {
    Episode(
      id: "preview-2",
      title: "SwiftUI Animation Techniques",
      podcastID: "podcast-2",
      podcastTitle: "iOS Dev Weekly",
      playbackPosition: 0,
      isPlayed: false,
      pubDate: Date(),
      duration: 2400,
      description: "Exploring animations in SwiftUI",
      audioURL: URL(string: "https://example.com/episode2.mp3"),
      artworkURL: nil
    )
  }
}
#endif
