#if os(iOS)
import Foundation
import SharedUtilities

/// Abstraction over the audio playback engine used by `EnhancedEpisodePlayer`.
///
/// `AVPlayerPlaybackEngine` is the production conformer; tests can inject a lightweight
/// mock to verify URL selection (local file vs. streaming) without requiring AVFoundation.
///
/// **Issue**: #28.1.13 — extracted to enable testable fallback-to-streaming logic.
@MainActor
public protocol AudioEngineProtocol: AnyObject {
    // MARK: - Callbacks

    /// Called periodically with current playback position (seconds).
    var onPositionUpdate: ((TimeInterval) -> Void)? { get set }

    /// Called when playback reaches the end of the audio.
    var onPlaybackFinished: (() -> Void)? { get set }

    /// Called when an error occurs (network failure, invalid URL, etc.).
    var onError: ((PlaybackError) -> Void)? { get set }

    // MARK: - State

    /// Whether audio is currently playing.
    var isPlaying: Bool { get }

    // MARK: - Playback Control

    /// Start playback from a URL at the given position and rate.
    func play(from url: URL, startPosition: TimeInterval, rate: Float)

    /// Pause playback.
    func pause()

    /// Seek to a specific position (seconds).
    func seek(to position: TimeInterval)

    /// Update playback rate (1.0 = normal, 2.0 = 2x speed).
    func setRate(_ rate: Float)

    /// Stop playback and release resources.
    func stop()
}
#endif
