# Customization and Personalization

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Customizing Settings Per Podcast](#customizing-settings-per-podcast)
- [Organizing Podcasts into Folders/Categories](#organizing-podcasts-into-folderscategories)
- [Creating Custom Playlists](#creating-custom-playlists)
- [Auto-Playlists](#auto-playlists)
- [Filtering Episodes by Keywords](#filtering-episodes-by-keywords)
- [Customizing Podcast Information (Metadata)](#customizing-podcast-information-metadata)
- [Managing Notifications](#managing-notifications)
- [Applying Custom Tags/Groups for Organization](#applying-custom-tagsgroups-for-organization)
- [Widget Customization (iOS Widgets, Google Assistant)](#widget-customization-ios-widgets-google-assistant)
- [Advanced Episode Filtering Across Library](#advanced-episode-filtering-across-library)
- [Siri, iOS Shortcuts, and Google Assistant Integration](#siri-ios-shortcuts-and-google-assistant-integration)
- [Apple Watch Support](#apple-watch-support)
- [Smart Recommendations](#smart-recommendations)
- [OPML Export](#opml-export)
- [Parental Controls and Content Filters](#parental-controls-and-content-filters)
- [Apple ID Sign-In and iCloud Sync](#apple-id-sign-in-and-icloud-sync)
- [In-App Help and Support](#in-app-help-and-support)
- [Accessibility for Customization Features](#accessibility-for-customization-features)

**Description:** Users can tailor app behavior and appearance, designed for iPhone/iOS conventions. Users can choose from available integrations for widgets and automation (e.g., iOS Widgets, Google Assistant, Siri).

## Background
- **Given:** App is launched on iPhone.
- **And:** At least one podcast subscribed.

## Scenarios

### Customizing Settings Per Podcast
- **Given:** Viewing subscribed podcasts.
- **When:** Opens "Custom Settings" for a podcast.
- **Then:** Can override global settings for that podcast.

### Organizing Podcasts into Folders/Categories
- **Given:** User has multiple podcasts.
- **When:** User creates folders or assigns categories.
- **Then:** Podcasts can be viewed and managed by folder/category.
- **And:** Folder organization persists after closing and reopening the app.

### Creating Custom Playlists
- **Given:** Multiple episodes available.
- **When:** Adds episodes to playlist, reorders, sorts, enables "Continuous Playback".
- **Then:** Plays episodes in order; can save/load multiple playlists.

### Auto-Playlists
- **Given:** User wants dynamic playlists (e.g., all new episodes, all downloaded).
- **When:** User enables auto-playlist in settings.
- **Then:** Playlist updates automatically as new episodes are added/downloaded.

### Filtering Episodes by Keywords
- **Given:** Viewing episode list.
- **When:** Enters keywords in filter.
- **Then:** List updates to show matching episodes.

### Customizing Podcast Information (Metadata)
- **Given:** Subscribed podcast.
- **When:** Modifies name, artwork, categories.
- **Then:** Metadata updates locally.

### Managing Notifications
- **Given:** Subscribed podcast.
- **When:** Configures notification settings.
- **Then:** Notifications delivered per preferences using iOS notification system.

### Applying Custom Tags/Groups for Organization
- **Given:** Multiple podcasts.
- **When:** Applies tags/groups.
- **Then:** Can filter/organize library.
- **And:** Tag assignments persist after closing and reopening the app.

### Widget Customization (iOS Widgets, Google Assistant)
- **Given:** User adds a Podcast Addict widget.
- **When:** User customizes widget size, content, and actions using iOS widget system or Google Assistant integration.
- **Then:** Widget displays personalized info and controls.

### Advanced Episode Filtering Across Library
- **Given:** Viewing overall episode list.
- **When:** Applies filters (duration, status, date, played/unplayed).
- **Then:** Only matching episodes are shown.

### Siri, iOS Shortcuts, and Google Assistant Integration
- **Given:** User wants to automate actions.
- **When:** Configures Siri, iOS Shortcuts, or Google Assistant.
- **Then:** App actions can be triggered via voice or automation.
- **Given:** User updates the podcast library (subscribe, unsubscribe, or metadata changes).
- **When:** Triggers a Siri or Shortcut action that queries the library.
- **Then:** Results reflect the latest library state.

### Apple Watch Support
- **Given:** User has an Apple Watch paired with their iPhone.
- **When:** Opens the Podcast Addict app on Apple Watch.
- **Then:** Can view playlists, tags, and perform quick actions (play, pause, skip, mark as played, add to playlist).

### Smart Recommendations
- **Given:** User has a listening history in the app.
- **When:** Navigates to the recommendations section or receives a suggestion.
- **Then:** App displays personalized podcast and episode recommendations based on history and preferences.

### OPML Export
- **Given:** User wants to back up or migrate podcast subscriptions.
- **When:** Selects "Export OPML" in settings.
- **Then:** App generates and saves an OPML file containing all subscriptions.

### Parental Controls and Content Filters
- **Given:** User wants to restrict explicit content or set parental controls.
- **When:** Enables parental controls or sets content filters in settings.
- **Then:** Explicit podcasts/episodes are hidden or restricted according to preferences.

### Apple ID Sign-In and iCloud Sync
- **Given:** User wants to sync customization settings across devices.
- **When:** Signs in with Apple ID and enables iCloud sync.
- **Then:** Customization settings are synced automatically across all devices.

### In-App Help and Support
- **Given:** User needs help or wants to provide feedback.
- **When:** Accesses the help/support section in the app.
- **Then:** Can view FAQ, contact support, and submit feedback directly.

### Accessibility for Customization Features
- **Given:** User has accessibility needs (e.g., uses VoiceOver, prefers large text, needs high contrast).
- **When:** Uses customization features in the app.
- **Then:** All controls and features are fully compatible with VoiceOver, Dynamic Type, and high-contrast color schemes.
