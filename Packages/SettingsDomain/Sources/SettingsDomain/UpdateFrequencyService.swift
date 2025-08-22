#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation
import CoreModels

/// Service for managing podcast update frequencies and schedules
@MainActor
public class UpdateFrequencyService {
    private let settingsManager: SettingsManager
    private var schedules: [String: UpdateSchedule] = [:]
    
    #if canImport(Combine)
    /// Publisher for reactive UI updates
    public private(set) var schedulesChangePublisher = PassthroughSubject<UpdateSchedule, Never>()
    #endif
    
    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }
    
    // MARK: - Schedule Computation
    
    /// Compute the next refresh time for a podcast
    public func computeNextRefreshTime(for podcastId: String) async -> Date? {
        let frequency = await settingsManager.effectiveUpdateFrequency(for: podcastId)
        
        // Manual frequency means no automatic refresh
        guard let _ = frequency.timeInterval else {
            return nil
        }
        
        // Get current schedule or create initial one
        let currentSchedule = schedules[podcastId] ?? UpdateSchedule.initialSchedule(for: podcastId, updateFrequency: frequency)
        
        return currentSchedule.nextDueDate
    }
    
    /// Mark a podcast as refreshed and update its schedule
    public func markPodcastRefreshed(_ podcastId: String) async {
        let frequency = await settingsManager.effectiveUpdateFrequency(for: podcastId)
        
        // Get existing schedule or create initial one if it doesn't exist
        let currentSchedule = schedules[podcastId] ?? UpdateSchedule.initialSchedule(for: podcastId, updateFrequency: frequency)
        
        let newSchedule = currentSchedule.scheduleAfterRefresh(updateFrequency: frequency)
        schedules[podcastId] = newSchedule
        
        // Debug: Verify the schedule was stored
        print("DEBUG: markPodcastRefreshed - stored schedule for \(podcastId): \(newSchedule)")
        print("DEBUG: markPodcastRefreshed - schedules dictionary now has \(schedules.count) entries")
        
        #if canImport(Combine)
        schedulesChangePublisher.send(newSchedule)
        #endif
    }
    
    /// Get list of podcast IDs due for update
    public func getPodcastsDueForUpdate() -> [String] {
        var duePodcasts: [String] = []
        
        for (podcastId, schedule) in schedules {
            if schedule.isDue {
                duePodcasts.append(podcastId)
            }
        }
        
        return duePodcasts
    }
    
    /// Initialize or update schedule for a podcast (called when subscription changes)
    public func initializeSchedule(for podcastId: String) async {
        if schedules[podcastId] == nil {
            let frequency = await settingsManager.effectiveUpdateFrequency(for: podcastId)
            let schedule = UpdateSchedule.initialSchedule(for: podcastId, updateFrequency: frequency)
            schedules[podcastId] = schedule
            #if canImport(Combine)
            schedulesChangePublisher.send(schedule)
            #endif
        }
    }
    
    /// Remove schedule for a podcast (called when unsubscribing)
    public func removeSchedule(for podcastId: String) {
        schedules.removeValue(forKey: podcastId)
    }
    
    /// Get current schedule for a podcast
    public func getSchedule(for podcastId: String) -> UpdateSchedule? {
        let schedule = schedules[podcastId]
        print("DEBUG: getSchedule for \(podcastId): \(schedule?.podcastId ?? "nil")")
        print("DEBUG: getSchedule - schedules dictionary has \(schedules.count) entries")
        return schedule
    }
    
    /// Update schedule when settings change (manual refresh of due calculations)
    public func refreshSchedules(for podcastIds: [String]) async {
        for podcastId in podcastIds {
            if let currentSchedule = schedules[podcastId] {
                let frequency = await settingsManager.effectiveUpdateFrequency(for: podcastId)
                
                // Recalculate next due date based on current frequency and last check
                let newNextDue = frequency.timeInterval.map {
                    currentSchedule.lastCheckedDate.addingTimeInterval($0)
                } ?? Date.distantFuture
                
                let updatedSchedule = UpdateSchedule(
                    podcastId: podcastId,
                    lastCheckedDate: currentSchedule.lastCheckedDate,
                    nextDueDate: newNextDue
                )
                
                schedules[podcastId] = updatedSchedule
                #if canImport(Combine)
                schedulesChangePublisher.send(updatedSchedule)
                #endif
            }
        }
    }
}
