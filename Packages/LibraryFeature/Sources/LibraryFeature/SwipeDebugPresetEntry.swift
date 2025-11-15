#if os(iOS)
  import CoreModels

  public struct SwipeDebugPresetEntry {
    public let title: String
    public let shortTitle: String
    public let identifier: String
    public let preset: SwipeActionSettings

    public init(title: String, shortTitle: String, identifier: String, preset: SwipeActionSettings)
    {
      self.title = title
      self.shortTitle = shortTitle
      self.identifier = identifier
      self.preset = preset
    }

    // MARK: - Preset Factory Methods

    public static var playback: SwipeDebugPresetEntry {
      SwipeDebugPresetEntry(
        title: "Preset · Playback",
        shortTitle: "Playback",
        identifier: "SwipeActions.Debug.ApplyPreset.Playback",
        preset: .playbackFocused
      )
    }

    public static var organization: SwipeDebugPresetEntry {
      SwipeDebugPresetEntry(
        title: "Preset · Organization",
        shortTitle: "Org",
        identifier: "SwipeActions.Debug.ApplyPreset.Organization",
        preset: .organizationFocused
      )
    }

    public static var download: SwipeDebugPresetEntry {
      SwipeDebugPresetEntry(
        title: "Preset · Download",
        shortTitle: "Download",
        identifier: "SwipeActions.Debug.ApplyPreset.Download",
        preset: .downloadFocused
      )
    }
  }
#endif
