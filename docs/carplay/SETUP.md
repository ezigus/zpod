# CarPlay Integration Setup Guide

## Overview
This document describes how to enable CarPlay support for the zPod podcast application. The infrastructure code has been created and is ready for CarPlay enablement.

## Current Status
- ✅ CarPlay infrastructure code created (`CarPlaySceneDelegate.swift`, `CarPlayEpisodeListController.swift`)
- ✅ Code uses conditional compilation (`#if canImport(CarPlay)`) to avoid build issues
- ⏳ CarPlay entitlements not yet added (requires Apple Developer Program enrollment)
- ⏳ Info.plist CarPlay configuration not yet added (to avoid CI build issues)
- ⏳ Full testing requires CarPlay simulator or physical hardware

## Prerequisites

### 1. Apple Developer Program
- Enroll in the Apple Developer Program
- Request CarPlay entitlement from Apple (https://developer.apple.com/contact/carplay/)
- Approval process can take several weeks

### 2. Development Environment
- Xcode 14.0 or later
- iOS 14.0+ deployment target
- CarPlay simulator or physical CarPlay-enabled vehicle for testing

## Setup Steps

### Step 1: Add CarPlay Entitlements

Add the following to `zpod/zpod.entitlements`:

```xml
<key>com.apple.developer.carplay-audio</key>
<true/>
```

### Step 2: Configure Info.plist

Add the following to `zpod/Info.plist` to declare CarPlay scene support:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UISceneConfigurations</key>
    <dict>
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>CPTemplateApplicationScene</string>
                <key>UISceneConfigurationName</key>
                <string>CarPlay</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

Also ensure the audio background mode is present (already configured):

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### Step 3: Update ZpodApp.swift

The app needs to be aware of CarPlay scenes. Add scene support to `ZpodApp.swift` if not already present:

```swift
import SwiftUI
#if canImport(CarPlay)
import CarPlay
#endif

@main
struct ZpodApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(podcastManager: Self.sharedPodcastManager)
        }
        #if canImport(LibraryFeature)
        .modelContainer(Self.sharedModelContainer)
        #endif
    }
}
```

Note: Scene configuration is handled via Info.plist, not programmatically.

### Step 3b: Provide CarPlay Dependencies

Configure shared dependencies so the CarPlay layer can access the user's podcast library and playback engine:

```swift
#if canImport(CarPlay)
import CarPlay
import LibraryFeature
#endif

@main
struct ZpodApp: App {
    #if canImport(LibraryFeature)
    private static let sharedPodcastManager = InMemoryPodcastManager()
    #endif

    init() {
        #if canImport(CarPlay)
        CarPlayDependencyRegistry.configure(podcastManager: Self.sharedPodcastManager)
        #endif
    }
}
```

> ⚠️ Replace the sample `InMemoryPodcastManager` with the production persistence layer when available. Call `configure(podcastManager:)` before CarPlay connects so the scene delegate resolves the correct dependencies.

### Step 4: Implement Podcast Loading

The current implementation has placeholder podcast loading. Update `CarPlaySceneDelegate.createPodcastSection()` to fetch real podcasts:

```swift
private func createPodcastSection() -> CPListSection {
    // Fetch podcasts from repository
    let podcastRepository = EpisodeListDependencyProvider.shared.podcastRepository
    let podcasts = podcastRepository.fetchAllPodcasts() // Implement this method
    
    let items: [CPListItem] = podcasts.map { podcast in
        let item = CPListItem(
            text: podcast.title,
            detailText: "\(podcast.episodeCount ?? 0) episodes",
            image: nil,  // Could add podcast artwork
            accessoryImage: nil,
            accessoryType: .disclosureIndicator
        )
        
        item.handler = { [weak self] _, completion in
            self?.showEpisodeList(for: podcast)
            completion()
        }
        
        return item
    }
    
    return CPListSection(items: items, header: "Your Podcasts", sectionIndexTitle: nil)
}
```

### Step 5: Implement Episode Loading

Update `CarPlayEpisodeListController.loadEpisodes()` to fetch real episodes:

```swift
private func loadEpisodes() async {
    do {
        episodes = try await episodeRepository.fetchEpisodes(for: podcast.id)
            .sorted { $0.publishedAt > $1.publishedAt }  // Most recent first
        Self.logger.info("Loaded \(self.episodes.count) episodes for podcast: \(self.podcast.title)")
    } catch {
        Self.logger.error("Failed to load episodes: \(error.localizedDescription)")
        episodes = []
    }
}
```

### Step 6: Add Siri Integration (Optional)

For voice control support, implement Siri intents:

1. Create intents definition file
2. Add intent handling to the app
3. Configure Info.plist for intent support

Example intent for "Play latest episode":
- Intent: PlayMediaIntent
- Parameter: Podcast name or "latest"

Once intents are configured, update `CarPlayDependencyRegistry.configure` to provide any intent handlers or voice metadata refresh hooks so the CarPlay scene can register new voice command variants.

## Testing

### CarPlay Simulator
1. Run the app in the iOS Simulator
2. From the Xcode menu: I/O → External Displays → CarPlay
3. The CarPlay interface should appear in a separate window
4. Test episode browsing and playback

### Physical CarPlay
1. Connect iPhone to CarPlay-enabled vehicle
2. Launch the app
3. Access the app from the CarPlay home screen
4. Verify episode list, playback, and voice controls

### Testing Checklist
- [ ] CarPlay interface appears when connected
- [ ] Podcast list displays correctly
- [ ] Episode list shows for selected podcast
- [ ] Large touch targets (minimum 44pt as per HIG)
- [ ] Text is readable (high contrast, appropriate font sizes)
- [ ] Playback starts when episode is selected
- [ ] Now Playing template shows current episode
- [ ] Voice control works for episode selection
- [ ] Interface complies with CarPlay HIG

## Architecture

### Components

1. **CarPlaySceneDelegate**
   - Manages CarPlay scene lifecycle
   - Sets up template hierarchy
   - Handles podcast library display

2. **CarPlayEpisodeListController**
   - Manages episode list for a specific podcast
   - Handles episode selection and playback
   - Formats episode metadata for CarPlay display

3. **Dependencies**
   - Uses existing `EpisodeRepository` for episode data
   - Uses existing `PlaybackService` for playback control
   - Leverages `EpisodeListDependencyProvider` for shared services

### Data Flow

```
CarPlay Connect
    ↓
CarPlaySceneDelegate.didConnect
    ↓
Setup Root Template (Tab Bar)
    ↓
Display Podcast Library List
    ↓
User Selects Podcast
    ↓
CarPlayEpisodeListController.createEpisodeListTemplate
    ↓
Display Episode List
    ↓
User Selects Episode
    ↓
PlaybackService.play(episode)
    ↓
Now Playing Template (system-provided)
```

## Safety and Compliance

### CarPlay HIG Requirements
- ✅ Large touch targets (44pt minimum)
- ✅ High contrast text
- ✅ Simplified interface (limited templates)
- ✅ Essential information only
- ✅ Limited list depth (max 100 items per list)

### Driver Distraction Prevention
- List items are limited to essential metadata
- No complex interactions while vehicle is in motion
- Voice control available for hands-free operation
- Quick episode selection (2 taps maximum)

## Troubleshooting

### CarPlay Interface Not Appearing
- Verify CarPlay entitlement is added
- Check Info.plist scene configuration
- Ensure app runs on iOS 14.0+
- Check Xcode console for errors

### Episodes Not Loading
- Verify `EpisodeRepository` is properly initialized
- Check episode data exists in persistence layer
- Review logs for error messages

### Playback Not Starting
- Verify `PlaybackService` is configured
- Check audio session configuration
- Ensure episode has valid audio URL

## Resources
- [Apple CarPlay Documentation](https://developer.apple.com/carplay/)
- [CarPlay Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/carplay)
- [CarPlay Framework Reference](https://developer.apple.com/documentation/carplay)
- [WWDC CarPlay Sessions](https://developer.apple.com/videos/frameworks/carplay)

## Future Enhancements
1. Add podcast artwork to list items
2. Implement Now Playing template customization
3. Add queue management from CarPlay
4. Support for advanced playback controls (speed, skip intervals)
5. Smart episode suggestions based on drive time
6. Integration with vehicle navigation for arrival-based episode recommendations

## Siri Integration Setup

### Overview
The Siri integration enables voice control for podcast playback via the `zpodIntents` extension. This allows natural language commands like "Play the latest episode of [podcast]" while connected to CarPlay.

### Prerequisites
- CarPlay setup completed (see above)
- Siri capability enabled in Apple Developer account
- App Groups configured for data sharing

### Step 1: Add Intents Extension to Xcode Project

1. Open `zpod.xcodeproj` in Xcode
2. File → New → Target
3. Select "Intents Extension"
4. Product Name: `zpodIntents`
5. Bundle ID: `us.zig.zpod.intents`
6. Check "Include UI Extension": **No**
7. Add to zpod app target

### Step 2: Configure Main App Entitlements

Add to `zpod/zpod.entitlements`:

```xml
<key>com.apple.developer.siri</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.us.zig.zpod</string>
</array>
```

### Step 3: Configure Extension Entitlements

Create `zpodIntents/zpodIntents.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.us.zig.zpod</string>
    </array>
</dict>
</plist>
```

### Step 4: Update Privacy Descriptions

Add to `zpod/Info.plist`:

```xml
<key>NSSiriUsageDescription</key>
<string>zpod uses Siri to control podcast playback with voice commands while driving.</string>
<key>NSMicrophoneUsageDescription</key>
<string>zpod needs microphone access for Siri voice commands.</string>
```

### Step 5: Link Extension Files

The extension files are already created in `zpodIntents/`:
- `IntentHandler.swift` - Main extension entry point
- `PlayMediaIntentHandler.swift` - Media playback intent handler
- `Info.plist` - Extension configuration
- `README.md` - Documentation

Add these files to the zpodIntents target in Xcode.

### Step 6: Link Shared Code

The extension needs access to podcast/episode data. In Xcode:

1. Select zpodIntents target
2. Build Phases → Link Binary With Libraries
3. Add framework: `SharedUtilities.framework`
4. Add framework: `CoreModels.framework`

### Step 7: Enable Siri Capability

1. Select zpod target in Xcode
2. Signing & Capabilities tab
3. Click "+ Capability"
4. Add "Siri"

### Testing Siri Integration

#### In Simulator
```bash
# Enable Siri in simulator
xcrun simctl spawn booted defaults write com.apple.Siri SiriEnabled -bool true

# Test voice commands (manual)
# Use Hardware → Siri or hold Home button
```

#### On Device
1. Settings → Siri & Search → Enable "Listen for 'Hey Siri'"
2. Open zpod and play an episode (this donates activity to Siri)
3. Wait 5-10 minutes for Siri to index
4. Test commands:
   - "Hey Siri, play the latest episode of [podcast name]"
   - "Hey Siri, play [episode title]"

#### Verify Donations
```bash
# View Siri donated shortcuts
# Settings → Siri & Search → zpod
# Should show recently played episodes as suggestions
```

### Troubleshooting Siri

**Extension doesn't load:**
- Verify bundle ID is `us.zig.zpod.intents`
- Check extension is embedded in main app
- Rebuild both app and extension

**No search results:**
- Verify app groups configured correctly
- Check shared data is accessible
- Add logging to `PlayMediaIntentHandler.searchMedia()`

**Siri doesn't recognize commands:**
- Ensure Siri permission granted
- Check media donations are being made (see logs)
- Try more specific podcast/episode names
- Wait longer after donations (can take time to index)

**Commands fail:**
- Check `zpod` is set as default podcast app in Settings
- Verify intent handler returns `.handleInApp` code
- Check main app handles NSUserActivity correctly

### Supported Voice Commands

The current implementation supports:
- "Play [podcast name]"
- "Play [episode title]"
- "Play the latest episode of [podcast]"

Future enhancements (not yet implemented):
- "Play my queue"
- "Play unplayed episodes"
- "Continue listening to podcasts"
- Multi-language support

### Implementation Notes

1. **Media Donations**: Automatically donated when playing episodes from CarPlay
2. **Fuzzy Matching**: Uses Levenshtein distance for typo tolerance (see `SiriMediaSearch.swift`)
3. **Temporal Queries**: Parses "latest", "newest", "recent" to find appropriate episodes
4. **Disambiguation**: Siri asks for clarification when multiple matches found

See `zpodIntents/README.md` for detailed architecture and implementation details.
