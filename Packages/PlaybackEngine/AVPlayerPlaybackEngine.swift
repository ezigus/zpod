#if os(iOS)
import AVFoundation
import Foundation
import OSLog
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

    public var isPlaying: Bool {
        (player?.rate ?? 0) > 0
    }

    public var debugStatusDescription: String {
        let status = lastStatus ?? playerItem?.status
        switch status {
        case .readyToPlay:
            return "readyToPlay"
        case .failed:
            return "failed"
        case .unknown:
            return "unknown"
        case .none:
            return "nil"
        @unknown default:
            return "unknown"
        }
    }

    public var debugRateDescription: String {
        guard let rate = player?.rate else { return "nil" }
        return String(format: "%.2f", rate)
    }

    public var debugErrorDescription: String {
        lastErrorDescription ?? playerItem?.error?.localizedDescription ?? "none"
    }
    
    // MARK: - Private Properties
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var didFinishObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var currentURL: URL?
    private var lastStatus: AVPlayerItem.Status?
    private var lastErrorDescription: String?
    
    private let timeObserverInterval: TimeInterval = 0.5
    
    /// Seek tolerance controls precision vs performance tradeoff.
    /// - `.zero`: Maximum precision (exact frame), higher CPU usage - best for podcasts
    /// - `.positiveInfinity`: Fast seeking, lower precision - best for music/video
    /// Default is .zero for podcast use case where exact position matters for chapter boundaries.
    public var seekTolerance: CMTime = .zero
    
    // MARK: - Initialization
    
    public init() {}

    private static let logger = Logger(
        subsystem: "us.zig.zpod",
        category: "AVPlayerPlaybackEngine"
    )
    
    deinit {
        // Cleanup must be called synchronously to ensure proper deallocation
        // We use assumeIsolated to assert we're on the main actor (which should
        // be true since @MainActor class instances are deallocated on main actor)
        MainActor.assumeIsolated {
            cleanupSync()
        }
    }
    
    // MARK: - Public Methods
    
    /// Start playback from a URL at the given position and rate.
    ///
    /// - Parameters:
    ///   - url: The audio stream URL
    ///   - startPosition: Initial playback position in seconds (default: 0)
    ///   - rate: Playback rate/speed (1.0 = normal, 2.0 = 2x speed)
    public func play(from url: URL, startPosition: TimeInterval = 0, rate: Float = 1.0) {
        // Diagnostic logging for test environment
        if ProcessInfo.processInfo.environment["UITEST_DEBUG_AUDIO"] == "1" {
            Logger.info("[TestAudio] AVPlayerPlaybackEngine.play(from: \(url.absoluteString), startPosition: \(startPosition), rate: \(rate))")
            NSLog("[TestAudio] AVPlayerPlaybackEngine.play(from: %@, startPosition: %f, rate: %f)", url.absoluteString, startPosition, rate)
        }
        
        // Clean up any existing playback
        cleanupSync()
        
        // Store URL for error logging
        currentURL = url
        
        if ProcessInfo.processInfo.environment["UITEST_DEBUG_AUDIO"] == "1" {
            // Check if file exists for file URLs (test diagnostics only)
            if url.isFileURL {
                let exists = FileManager.default.fileExists(atPath: url.path)
                NSLog("[TestAudio] File URL check: %@ exists=%@", url.path, exists ? "YES" : "NO")
                if !exists {
                    NSLog("[TestAudio][Error] File does not exist at path: %@", url.path)
                }
            }
        }
        
        // Activate audio session
        activateAudioSession()
        
        // Create player item and player
        playerItem = AVPlayerItem(url: url)
        lastStatus = playerItem?.status
        lastErrorDescription = nil
        player = AVPlayer(playerItem: playerItem)
        
        // Observe player item status for errors
        observePlayerStatus()
        observePlayerItemFailure()
        
        // Observe playback completion
        observePlaybackCompletion()
        
        // Add periodic time observer for position updates
        addTimeObserver()
        
        // Seek to start position if non-zero, then start playback after seek completes
        if startPosition > 0 {
            let time = CMTime(seconds: startPosition, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: time, toleranceBefore: seekTolerance, toleranceAfter: seekTolerance) { [weak self] finished in
                guard finished, let self = self else { return }
                // Seek completed, now start playback at the requested rate
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.player?.play()
                    self.player?.rate = rate
                }
            }
        } else {
            // No seek needed, start playback immediately
            player?.play()
            player?.rate = rate
        }
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
    /// 
    /// This method is nonisolated to allow safe cleanup from deinit contexts.
    /// Cleanup operations are dispatched to the main actor when needed.
    nonisolated public func stop() {
        Task { @MainActor in
            // Pause playback first to stop audio output
            player?.pause()
            cleanupSync()
        }
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
            
            // Validate time before converting to avoid NaN/infinity
            guard time.isValid, time.isNumeric else {
                Logger.warning("Invalid time from observer: \(time)")
                return
            }
            
            let seconds = CMTimeGetSeconds(time)
            
            // Validate seconds value
            guard seconds.isFinite, seconds >= 0 else {
                Logger.warning("Non-finite or negative seconds: \(seconds)")
                return
            }
            
            // Explicitly dispatch to main actor for callback
            Task { @MainActor [weak self] in
                self?.onPositionUpdate?(seconds)
            }
        }
    }
    
    private func observePlayerStatus() {
        guard let playerItem = playerItem else { return }
        
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let error = item.error
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.lastStatus = status

                // Diagnostic logging for test environment
                if ProcessInfo.processInfo.environment["UITEST_DEBUG_AUDIO"] == "1" {
                    Logger.info("[TestAudio] AVPlayerItem status changed to: \(status.rawValue)")
                }

                switch status {
                case .failed:
                    if ProcessInfo.processInfo.environment["UITEST_DEBUG_AUDIO"] == "1" {
                        NSLog("[TestAudio][Error] AVPlayerItem FAILED: %@", error?.localizedDescription ?? "Unknown error")
                    }
                    self.lastErrorDescription = error?.localizedDescription
                    let nsError = error as NSError?
                    let playbackError = nsError.map { self.mapAVError($0) } ?? .streamFailed
                    self.logPlaybackFailure(playbackError, underlying: nsError)

                    // Additional diagnostic for tests
                    if ProcessInfo.processInfo.environment["UITEST_DEBUG_AUDIO"] == "1" {
                        Logger.error("[TestAudio][Error] AVPlayerItem FAILED: \(error?.localizedDescription ?? "Unknown error")")
                    }

                    self.onError?(playbackError)

                case .readyToPlay:
                    Logger.debug("AVPlayer ready to play")

                    // Additional diagnostic for tests
                    if ProcessInfo.processInfo.environment["UITEST_DEBUG_AUDIO"] == "1" {
                        Logger.info("[TestAudio] AVPlayerItem ready to play")
                    }

                case .unknown:
                    break

                @unknown default:
                    break
                }
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
            // Explicitly dispatch to main actor for callback
            Task { @MainActor [weak self] in
                self?.onPlaybackFinished?()
            }
        }
    }

    private func observePlayerItemFailure() {
        guard let playerItem = playerItem else { return }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            Task { @MainActor [weak self] in
                let playbackError = error.flatMap { self?.mapAVError($0) } ?? .streamFailed
                self?.logPlaybackFailure(playbackError, underlying: error)
                self?.onError?(playbackError)
            }
        }
    }

    func mapAVError(_ error: NSError) -> PlaybackError {
        switch (error.domain, error.code) {
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet),
             (NSURLErrorDomain, NSURLErrorNetworkConnectionLost),
             (NSURLErrorDomain, NSURLErrorCannotFindHost),
             (NSURLErrorDomain, NSURLErrorCannotConnectToHost):
            return .networkError

        case (NSURLErrorDomain, NSURLErrorTimedOut):
            return .timeout

        case (AVFoundationErrorDomain, _):
            return .streamFailed

        default:
            let message = error.localizedDescription
            return .unknown(message: message.isEmpty ? nil : message)
        }
    }

    private func logPlaybackFailure(_ playbackError: PlaybackError, underlying: NSError?) {
        let urlString = currentURL?.absoluteString ?? "unknown"
        let domain = underlying?.domain ?? "unknown"
        let code = underlying?.code ?? 0
        let description = underlying?.localizedDescription ?? "unknown"

        Self.logger.error("""
            AVPlayer playback failed:
            - url: \(urlString, privacy: .public)
            - error: \(playbackError)
            - underlying: \(description, privacy: .public)
            - domain: \(domain, privacy: .public) code: \(code, privacy: .public)
            """
        )
    }
    
    private func cleanupSync() {
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
        if let failureObserver = failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
            self.failureObserver = nil
        }
        
        // Stop and release player
        player?.pause()
        player = nil
        playerItem = nil
        currentURL = nil
        lastStatus = nil
        lastErrorDescription = nil
    }
}
#endif
