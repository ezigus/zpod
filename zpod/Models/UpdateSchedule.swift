import Foundation

/// Tracks podcast refresh schedule and timing
public struct UpdateSchedule: Codable, Equatable, Sendable {
    /// The podcast ID this schedule tracks
    public let podcastId: String
    /// When the podcast was last checked for updates
    public let lastCheckedDate: Date
    /// When the next update is due
    public let nextDueDate: Date
    
    public init(
        podcastId: String,
        lastCheckedDate: Date,
        nextDueDate: Date
    ) {
        self.podcastId = podcastId
        self.lastCheckedDate = lastCheckedDate
        self.nextDueDate = nextDueDate
    }
    
    /// Create a schedule for a podcast that has never been checked
    public static func initialSchedule(for podcastId: String, updateFrequency: UpdateFrequency) -> UpdateSchedule {
        let now = Date()
        let nextDue = updateFrequency.timeInterval.map { now.addingTimeInterval($0) } ?? Date.distantFuture
        
        return UpdateSchedule(
            podcastId: podcastId,
            lastCheckedDate: now,
            nextDueDate: nextDue
        )
    }
    
    /// Create an updated schedule after a podcast has been refreshed
    public func scheduleAfterRefresh(updateFrequency: UpdateFrequency) -> UpdateSchedule {
        let now = Date()
        // Ensure the new lastCheckedDate is after the original by adding a small buffer
        let newLastChecked = max(now, lastCheckedDate.addingTimeInterval(0.001))
        let nextDue = updateFrequency.timeInterval.map { newLastChecked.addingTimeInterval($0) } ?? Date.distantFuture
        
        return UpdateSchedule(
            podcastId: podcastId,
            lastCheckedDate: newLastChecked,
            nextDueDate: nextDue
        )
    }
    
    /// Check if this podcast is due for an update
    public var isDue: Bool {
        return Date() >= nextDueDate
    }
}
