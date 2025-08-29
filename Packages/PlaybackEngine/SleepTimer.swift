#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation

/// Sleep timer service for automatic playback stopping
@MainActor
public final class SleepTimer {
    #if canImport(Combine)
    /// Published remaining time in seconds
    @Published public private(set) var remainingTime: TimeInterval = 0
    
    /// Published timer active state
    @Published public private(set) var isActive: Bool = false
    #else
    /// Remaining time in seconds (non-Combine version)
    public private(set) var remainingTime: TimeInterval = 0
    
    /// Timer active state (non-Combine version)
    public private(set) var isActive: Bool = false
    #endif
    
    /// Callback to trigger when timer expires
    public var onTimerExpired: (@Sendable () -> Void)?
    
    private var timer: Timer?
    private var originalDuration: TimeInterval = 0
    
    public init() {}
    
    /// Start sleep timer with specified duration
    public func start(duration: TimeInterval) {
        stop() // Cancel any existing timer
        
        guard duration > 0 else { return }
        
        originalDuration = duration
        remainingTime = duration
        isActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    /// Stop the sleep timer
    public func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingTime = 0
        originalDuration = 0
    }
    
    /// Reset timer to original duration (used for shake-to-reset feature)
    public func reset() {
        guard isActive, originalDuration > 0 else { return }
        remainingTime = originalDuration
    }
    
    /// Extend timer by additional time
    public func extend(by additionalTime: TimeInterval) {
        guard isActive else { return }
        remainingTime += additionalTime
        originalDuration += additionalTime
    }
    
    private func tick() {
        guard isActive else { return }
        
        remainingTime -= 1
        
        if remainingTime <= 0 {
            stop()
            onTimerExpired?()
        }
    }
}

/// Extension for common timer durations
public extension SleepTimer {
    static let commonDurations: [TimeInterval] = [
        5 * 60,    // 5 minutes
        10 * 60,   // 10 minutes
        15 * 60,   // 15 minutes
        30 * 60,   // 30 minutes
        45 * 60,   // 45 minutes
        60 * 60,   // 1 hour
        90 * 60,   // 1.5 hours
        120 * 60   // 2 hours
    ]
    
    /// Format duration for display (e.g., "1h 30m", "45m", "5m")
    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}
