# User Interface and Experience

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Navigating with CarPlay Layout](#navigating-with-carplay-layout)
- [Voice Control for Search (Siri Integration)](#voice-control-for-search-siri-integration)
- [Managing Ads (Free Version)](#managing-ads-free-version)
- [Using Home Screen Widgets (iOS Widgets)](#using-home-screen-widgets-ios-widgets)
- [Customizing App Theme and Appearance](#customizing-app-theme-and-appearance)
- [Controlling Playback via Headphones/Bluetooth](#controlling-playback-via-headphonesbluetooth)
- [Using Lock Screen and Control Center Players](#using-lock-screen-and-control-center-players)
- [Using App Shortcuts (iOS Quick Actions)](#using-app-shortcuts-ios-quick-actions)
- [Leveraging Accessibility Options](#leveraging-accessibility-options)
- [Optimizing for iPad UI](#optimizing-for-ipad-ui)
- [Customizing Swipe Gestures](#customizing-swipe-gestures)
- [Casting to External Devices (AirPlay, Chromecast)](#casting-to-external-devices-airplay-chromecast)
- [Apple Watch Support](#apple-watch-support)
- [Notification Actions](#notification-actions)
- [Siri and Shortcuts Integration](#siri-and-shortcuts-integration)
- [Smart Recommendations](#smart-recommendations)
- [Parental Controls and Content Filters](#parental-controls-and-content-filters)
- [Apple ID Sign-In and iCloud Sync](#apple-id-sign-in-and-icloud-sync)
- [In-App Help and Support](#in-app-help-and-support)
- [Accessibility for UI Features](#accessibility-for-ui-features)
- [Mini-Player and Expanded Player UI](#mini-player-and-expanded-player-ui)
  - [Mini-Player Shows Current Playback State](#mini-player-shows-current-playback-state)
  - [Mini-Player Controls](#mini-player-controls)
  - [Expanded Player Real-Time Updates](#expanded-player-real-time-updates)
  - [Player Error State Display](#player-error-state-display)
  - [Mini-Player Persistence](#mini-player-persistence)

**Description:** User-friendly interface with navigation and accessibility options, designed for iPhone/iOS conventions. Users can choose from available integrations for casting (e.g., AirPlay, Chromecast).

## Background
- **Given:** App is launched on iPhone.

## Scenarios

### Navigating with CarPlay Layout
- **Given:** In driving environment.
- **When:** Connects to Apple CarPlay.
- **Then:** Simplified, car-optimized interface with large buttons and essential controls is shown.

### Voice Control for Search (Siri Integration)
- **Given:** Wants to search for podcasts/episodes.
- **When:** Uses Siri or in-app voice command.
- **Then:** App performs search and displays results.

### Managing Ads (Free Version)
- **Given:** Using free version.
- **Then:** Banner or interstitial ads are shown (configurable).
- **When:** Upgrades to premium.
- **Then:** Ads are removed.

### Using Home Screen Widgets (iOS Widgets)
- **Given:** On iPhone home screen.
- **When:** Adds Podcast Addict widget via iOS widget system.
- **Then:** Widget displays info and controls.

### Customizing App Theme and Appearance
- **Given:** In "Settings" menu.
- **When:** Changes theme, layout, colors, font size.
- **Then:** App appearance updates, supporting iOS dark/light mode.

### Controlling Playback via Headphones/Bluetooth
- **Given:** Episode is playing.
- **When:** Uses external device controls.
- **Then:** App responds to play/pause/skip.

### Using Lock Screen and Control Center Players
- **Given:** Episode is playing in background.
- **When:** Views lock screen or Control Center.
- **Then:** Playback controls are available via iOS media controls.

### Using App Shortcuts (iOS Quick Actions)
- **Given:** On home screen.
- **When:** Long-presses app icon.
- **Then:** iOS Quick Actions appear for fast access to common features.

### Leveraging Accessibility Options
- **Given:** Has accessibility needs.
- **When:** Uses iOS system accessibility features.
- **Then:** App is compatible and usable (VoiceOver, Dynamic Type, etc.).

### Optimizing for iPad UI
- **Given:** Using app on iPad.
- **Then:** UI adapts for larger screen, supporting Split View and Slide Over.

### Customizing Swipe Gestures
- **Given:** On player or episode list.
- **When:** Customizes gesture actions.
- **Then:** App responds to gestures as configured.

### Casting to External Devices (AirPlay, Chromecast)
- **Given:** Connected to AirPlay, Chromecast, or other supported device.
- **When:** Taps "Cast" and selects device from UI.
- **Then:** Audio/video streams to the chosen device.

### Apple Watch Support
- **Given:** User has an Apple Watch paired with their iPhone.
- **When:** Opens the Podcast Addict app on Apple Watch.
- **Then:** Can access playback controls, quick actions, and notifications.

### Notification Actions
- **Given:** User receives a podcast notification on iOS.
- **When:** Interacts with the notification.
- **Then:** Can play, skip, or mark episodes as played directly from the notification.

### Siri and Shortcuts Integration
- **Given:** User wants to trigger UI actions via voice or automation.
- **When:** Configures Siri or iOS Shortcuts for UI actions.
- **Then:** Can open playlists, search, subscribe, and more via Siri or Shortcuts.

### Smart Recommendations
- **Given:** User has a listening history in the app.
- **When:** Navigates to the recommendations section or receives a suggestion.
- **Then:** App displays personalized podcast and episode recommendations based on history and preferences.

### Parental Controls and Content Filters
- **Given:** User wants to restrict explicit content or set parental controls.
- **When:** Enables parental controls or sets content filters in settings.
- **Then:** Explicit podcasts/episodes are hidden or restricted according to preferences.

### Apple ID Sign-In and iCloud Sync
- **Given:** User wants to sync UI settings across devices.
- **When:** Signs in with Apple ID and enables iCloud sync.
- **Then:** UI settings are synced automatically across all devices.

### In-App Help and Support
- **Given:** User needs help or wants to provide feedback.
- **When:** Accesses the help/support section in the app.
- **Then:** Can view FAQ, contact support, and submit feedback directly.

### Accessibility for UI Features
- **Given:** User has accessibility needs (e.g., uses VoiceOver, prefers large text, needs high contrast).
- **When:** Uses UI features in the app.
- **Then:** All controls and features are fully compatible with VoiceOver, Dynamic Type, and high-contrast color schemes.

## Additional UI Capabilities

### Customizable Home Screen Sections
- Users can show/hide sections such as categories, playlists, statistics, recommendations, and more on the app home screen.

### Episode List Sorting and Filtering
- Users can sort and filter episode lists by date, duration, played/unplayed status, download status, and more.

### Accessibility Features
- App supports screen readers (VoiceOver), high contrast mode, and large font options for improved accessibility.

### Multi-Select Actions
- Users can select multiple episodes or podcasts to perform bulk actions (delete, mark as played/unplayed, download, etc.).

### Episode Badges and Indicators
- Visual indicators for downloaded, new, in progress, played/unplayed episodes in lists.

### Episode List Inline Actions
- **Given:** Viewing a podcast's episode list.
- **When:** An episode row is visible.
- **Then:** The row shows an inline action cluster with Play/Pause, Favorite (heart), and Bookmark/Tag controls.
- **And:** The Play control reflects state (Play icon when idle, Pause icon when playing that episode).
- **And:** Favorite and Bookmark controls reflect state and expose accessibility labels with current state.

### Customizable Swipe Actions
- Users can configure swipe actions in episode and podcast lists (e.g., swipe to delete, archive, mark as played).

### Mini-Player and Expanded Player UI

The mini-player and expanded player provide persistent access to playback controls throughout the app.

#### Mini-Player Shows Current Playback State
- **Given:** An episode is playing.
- **When:** User views any tab in the app.
- **Then:** The mini-player displays the episode title.
- **And:** The mini-player shows the current position/duration.
- **And:** The progress bar reflects actual playback progress.
- **And:** The play/pause button reflects current state.

#### Mini-Player Controls
- **Given:** The mini-player is visible.
- **When:** User taps the play/pause button.
- **Then:** Playback toggles accordingly.
- **And:** The button icon updates to reflect new state.

#### Expanded Player Real-Time Updates
- **Given:** The expanded player is open.
- **When:** Playback is in progress.
- **Then:** The scrubber position updates in real-time.
- **And:** The elapsed time label updates every second.
- **And:** Seeking via scrubber updates playback position.

#### Player Error State Display
- **Given:** Playback has failed with an error.
- **When:** User views the mini-player or expanded player.
- **Then:** An error message is displayed.
- **And:** A retry button is shown (for recoverable errors).
- **And:** VoiceOver announces the error state.

#### Mini-Player Persistence
- **Given:** An episode is playing or paused.
- **When:** User navigates between tabs.
- **Then:** The mini-player remains visible at the bottom.
- **And:** Playback state is preserved.

### Podcast Artwork Display Options
- Users can choose grid or list layouts, adjust artwork size, and toggle artwork visibility.

### Quick Actions and Context Menus
- Long-press or context menu actions for episodes and podcasts (e.g., share, add to playlist, view details).

### iPad and Large Screen Layouts
- Optimized layouts for iPad and large screens, including multi-pane navigation and adaptive UI.
