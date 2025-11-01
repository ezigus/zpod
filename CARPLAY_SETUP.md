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
            ContentView()
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
