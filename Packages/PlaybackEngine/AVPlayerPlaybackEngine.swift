#if os(iOS)
import AVFoundation
import Foundation
import SharedUtilities

/// Production audio playback engine using AVPlayer.
///
/// This engine provides actual audio streaming from episode URLs, replacing
/// the simulated playback of EnhancedEpisodePlayer's ticker-based system.
///
/// **Features**:
/// - Streams audio from URLs using AVPlayer
/// - Periodic position updates (0.5s intervals)
/// - Error detection via KVO on player status
/// - Playback speed control
/// - Seek functionality
/// - Resource cleanup on stop/deinit
///
/// **Integration**:
/// Used by EnhancedEpisodePlayer as an optional audio backend. When provided,
/// it replaces the TimerTicker with actual audio playback and real position
/// observation from AVPlayer.
///
/// **Audio Session**:
/// Expects audio session to be configured by SystemMediaCoordinator.
/// Only activates the session when starting playback.
@MainActor
public final class AVPlayerPlaybackEngine {
    // MARK: - Public Callbacks
    
    /// Called periodically (every ~0.5s) with current playback position
    public var onPositionUpdate: ((TimeInterval) -> Void)?
    
    /// Called when playback reaches the end of the audio
    public var onPlaybackFinished: (() -> Void)?
    
    /// Called when an error occurs (network failure, invalid URL, etc.)
    public var onError: ((PlaybackError) -> Void)?
    
    // MARK: - Public Properties
    
    /// Current playback position in seconds
    public var currentPosition: TimeInterval {
        guard let player = player else { return 0 }
        let time = player.currentTime()
        return CMTimeGetSeconds(time)
    }
    
    // MARK: - Private Properties
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var didFinishObserver: NSObjectProtocol?
    private var currentURL: URL?
    
    private let timeObserverInterval: TimeInterval = 0.5
    
    /// Seek tolerance controls precision vs performance tradeoff.
    /// - `.zero`: Maximum precision (exact frame), higher CPU usage - best for podcasts
    /// - `.positiveInfinity`: Fast seeking, lower precision - best for music/video
    /// Default is .zero for podcast use case where exact position matters for chapter boundaries.
    public var seekTolerance: CMTime = .zero
    
    // MARK: - Initialization
    
    public init() {}
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// Start playback from a URL at the given position and rate.
    ///
    /// - Parameters:
    ///   - url: The audio stream URL
    ///   - startPosition: Initial playback position in seconds (default: 0)
    ///   - rate: Playback rate/speed (1.0 = normal, 2.0 = 2x speed)
    public func play(from url: URL, startPosition: TimeInterval = 0, rate: Float = 1.0) {
        // Clean up any existing playback
        cleanup()
        
        // Store URL for error logging
        currentURL = url
        
        // Activate audio session
        activateAudioSession()
        
        // Create player item and player
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Observe player item status for errors
        observePlayerStatus()
        
        // Observe playback completion
        observePlaybackCompletion()
        
        // Add periodic time observer for position updates
        addTimeObserver()
        
        // Seek to start position if non-zero
        if startPosition > 0 {
            let time = CMTime(seconds: startPosition, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: time, toleranceBefore: seekTolerance, toleranceAfter: seekTolerance)
        }
        
        // Set playback rate and start playing
        player?.rate = rate
        player?.play()
    }
    
    /// Pause playback.
    public func pause() {
        player?.pause()
    }
    
    /// Seek to a specific position.
    ///
    /// - Parameter position: Target position in seconds
    /// - Note: Uses `seekTolerance` property to control precision vs performance
    public func seek(to position: TimeInterval) {
        guard let player = player else { return }
        
        let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time, toleranceBefore: seekTolerance, toleranceAfter: seekTolerance)
    }
    
    /// Update playback rate (speed).
    ///
    /// - Parameter rate: New playback rate (1.0 = normal, 2.0 = 2x speed)
    public func setRate(_ rate: Float) {
        player?.rate = rate
    }
    
    /// Stop playback and release all resources.
    public func stop() {
        cleanup()
    }
    
    // MARK: - Private Methods
    
    /// Activates the audio session for playback.
    ///
    /// **Note**: This method only activates the session. Audio session category and mode
    /// are configured by `SystemMediaCoordinator` at app launch with `.playback` category
    /// and `.spokenAudio` mode. This design centralizes audio session configuration and
    /// prevents conflicts between multiple audio components.
    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.warning("Failed to activate audio session: \(error)")
        }
    }
    
    private func addTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(
            seconds: timeObserverInterval,
            preferredTimescale: CMTimeScale(NSEC_PER_SEC)
        )
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            self.onPositionUpdate?(seconds)
        }
    }
    
    private func observePlayerStatus() {
        guard let playerItem = playerItem else { return }
        
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            
            switch item.status {
            case .failed:
                let error = item.error
                let urlString = self.currentURL?.absoluteString ?? "unknown"
                Logger.error("AVPlayer failed for URL \(urlString): \(error?.localizedDescription ?? "Unknown error")")
                // KVO callbacks can fire on background threads. Since this class is @MainActor
                // and onError callback may access UI, we must dispatch to main actor.
                Task { @MainActor [weak self] in
                    self?.onError?(.streamFailed)
                }
                
            case .readyToPlay:
                Logger.debug("AVPlayer ready to play")
                
            case .unknown:
                break
                
            @unknown default:
                break
            }
        }
    }
    
    private func observePlaybackCompletion() {
        guard let playerItem = playerItem else { return }
        
        didFinishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Logger.debug("Playback finished")
            self.onPlaybackFinished?()
        }
    }
    
    private func cleanup() {
        // Remove time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Remove status observer
        statusObserver?.invalidate()
        statusObserver = nil
        
        // Remove completion observer
        if let didFinishObserver = didFinishObserver {
            NotificationCenter.default.removeObserver(didFinishObserver)
            self.didFinishObserver = nil
        }
        
        // Stop and release player
        player?.pause()
        player = nil
        playerItem = nil
        currentURL = nil
    }
}
#endif
