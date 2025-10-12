import CoreModels
import OSLog

@MainActor
public final class NotificationsConfigurationController: ObservableObject, FeatureConfigurationControlling {
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "NotificationsConfigurationController")

  @Published public private(set) var draft: NotificationSettings
  @Published private(set) var baseline: NotificationSettings
  @Published public private(set) var isSaving = false

  public var hasUnsavedChanges: Bool { draft != baseline }

  public var newEpisodeNotificationsEnabled: Bool { draft.newEpisodeNotificationsEnabled }
  public var downloadCompleteNotificationsEnabled: Bool { draft.downloadCompleteNotificationsEnabled }
  public var playbackNotificationsEnabled: Bool { draft.playbackNotificationsEnabled }
  public var quietHoursEnabled: Bool { draft.quietHoursEnabled }
  public var deliverySchedule: NotificationDeliverySchedule { draft.deliverySchedule }
  public var focusModeIntegrationEnabled: Bool { draft.focusModeIntegrationEnabled }
  public var liveActivitiesEnabled: Bool { draft.liveActivitiesEnabled }
  public var soundEnabled: Bool { draft.soundEnabled ?? true }

  public var quietHoursStart: Date { time(from: draft.quietHoursStart, fallbackHour: 22) }
  public var quietHoursEnd: Date { time(from: draft.quietHoursEnd, fallbackHour: 8) }

  private let service: NotificationsConfigurationServicing
  private var updatesTask: Task<Void, Never>?
  private let calendar: Calendar

  public init(
    service: NotificationsConfigurationServicing,
    calendar: Calendar = .current
  ) {
    self.service = service
    self.calendar = calendar
    self.draft = NotificationSettings.default
    self.baseline = NotificationSettings.default
    startObservingUpdates()
  }

  deinit {
    updatesTask?.cancel()
  }

  public func loadBaseline() async {
    let settings = await service.load()
    applyBaseline(settings)
  }

  public func bootstrap(with settings: NotificationSettings) {
    applyBaseline(settings)
  }

  public func resetToBaseline() async {
    draft = baseline
  }

  public func setNewEpisodeNotificationsEnabled(_ enabled: Bool) {
    updateDraft { $0.newEpisodeNotificationsEnabled = enabled }
  }

  public func setDownloadCompleteNotificationsEnabled(_ enabled: Bool) {
    updateDraft { $0.downloadCompleteNotificationsEnabled = enabled }
  }

  public func setPlaybackNotificationsEnabled(_ enabled: Bool) {
    updateDraft { $0.playbackNotificationsEnabled = enabled }
  }

  public func setQuietHoursEnabled(_ enabled: Bool) {
    updateDraft { $0.quietHoursEnabled = enabled }
  }

  public func setQuietHoursStart(_ date: Date) {
    updateDraft { $0.quietHoursStart = format(date) }
  }

  public func setQuietHoursEnd(_ date: Date) {
    updateDraft { $0.quietHoursEnd = format(date) }
  }

  public func setSoundEnabled(_ enabled: Bool) {
    updateDraft { $0.soundEnabled = enabled }
  }

  public func setDeliverySchedule(_ schedule: NotificationDeliverySchedule) {
    updateDraft { $0.deliverySchedule = schedule }
  }

  public func setFocusModeIntegrationEnabled(_ enabled: Bool) {
    updateDraft { $0.focusModeIntegrationEnabled = enabled }
  }

  public func setLiveActivitiesEnabled(_ enabled: Bool) {
    updateDraft { $0.liveActivitiesEnabled = enabled }
  }

  public func commitChanges() async {
    guard hasUnsavedChanges else { return }
    isSaving = true
    defer { isSaving = false }
    NotificationsConfigurationController.logger.debug("Saving notification settings")
    await service.save(draft)
    applyBaseline(draft)
  }

  private func updateDraft(_ mutation: (inout NotificationSettings) -> Void) {
    var updated = draft
    mutation(&updated)
    draft = updated
  }

  private func applyBaseline(_ settings: NotificationSettings) {
    baseline = settings
    draft = settings
  }

  private func startObservingUpdates() {
    updatesTask = Task { [weak self] in
      guard let self else { return }
      var iterator = service.updatesStream().makeAsyncIterator()
      while let next = await iterator.next() {
        await MainActor.run { [weak self] in
          self?.applyBaseline(next)
        }
      }
    }
  }

  private func time(from string: String, fallbackHour: Int) -> Date {
    if let date = Self.timeFormatter.date(from: string) {
      return mapTimeToToday(date)
    }
    return fallbackTime(hour: fallbackHour)
  }

  private func format(_ date: Date) -> String {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    guard let hour = components.hour, let minute = components.minute,
          let normalizedDate = calendar.date(from: DateComponents(hour: hour, minute: minute))
    else {
      return Self.timeFormatter.string(from: date)
    }
    return Self.timeFormatter.string(from: normalizedDate)
  }

  private func fallbackTime(hour: Int) -> Date {
    var components = calendar.dateComponents([.year, .month, .day], from: Date())
    components.hour = hour
    components.minute = 0
    if let date = calendar.date(from: components) {
      return date
    }
    return Date()
  }

  private func mapTimeToToday(_ date: Date) -> Date {
    let original = calendar.dateComponents([.hour, .minute], from: date)
    return fallbackTime(hour: original.hour ?? 0).addingTimeInterval(Double(original.minute ?? 0) * 60)
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "HH:mm"
    return formatter
  }()
}

