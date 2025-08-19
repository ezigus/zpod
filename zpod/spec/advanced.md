# Advanced User Tools

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Using Bookmarks](#using-bookmarks)
- [Archiving/Hiding Episodes](#archivinghiding-episodes)
- [Tracking Playback Statistics](#tracking-playback-statistics)
- [Exporting Statistics](#exporting-statistics)
- [Applying Custom Audio Effects](#applying-custom-audio-effects)
- [Casting to External Devices (AirPlay, Chromecast)](#casting-to-external-devices-airplay-chromecast)
- [Rating and Reviewing Podcasts](#rating-and-reviewing-podcasts)
- [Sharing Podcasts or Episodes](#sharing-podcasts-or-episodes)
- [Sharing Audio Clips](#sharing-audio-clips)
- [Podcast Addict API Integration (iOS Shortcuts, Google Assistant)](#podcast-addict-api-integration-ios-shortcuts-google-assistant)
- [Accessing Error Reports and Logs](#accessing-error-reports-and-logs)
- [Accessing Playback History](#accessing-playback-history)
- [Exporting User Data](#exporting-user-data)
- [Playback Progress Sync (Clarification)](#playback-progress-sync-clarification)
- [Apple Watch Support](#apple-watch-support)
- [OPML Export](#opml-export)
- [Smart Recommendations](#smart-recommendations)
- [Parental Controls and Content Filters](#parental-controls-and-content-filters)
- [Apple ID Sign-In and iCloud Sync](#apple-id-sign-in-and-icloud-sync)
- [In-App Help and Support](#in-app-help-and-support)
- [Accessibility for Advanced Features](#accessibility-for-advanced-features)

**Description:** Advanced features for power users, designed for iPhone/iOS conventions. Users can choose from available integrations for casting and automation (e.g., AirPlay, Chromecast, iOS Shortcuts, Google Assistant).

## Background
- **Given:** App is launched on iPhone.
- **And:** At least one episode available.

## Scenarios

### Using Bookmarks
- **Given:** Episode is playing.
- **When:** Taps "Bookmark".
- **Then:** Bookmark created; can resume or share segment.

### Archiving/Hiding Episodes
- **Given:** User wants to hide episodes without deleting.
- **When:** User archives or hides episodes.
- **Then:** Episodes are removed from main view but not deleted.

### Tracking Playback Statistics
- **Given:** Has listened to podcasts.
- **When:** Views "Playback Statistics".
- **Then:** Sees listening habits and stats.

### Exporting Statistics
- **Given:** User wants to analyze listening habits.
- **When:** User exports statistics.
- **Then:** App generates a file with playback data.

### Applying Custom Audio Effects
- **Given:** Episode is playing.
- **When:** Adjusts equalizer/pitch.
- **Then:** Audio output is modified.

### Casting to External Devices (AirPlay, Chromecast)
- **Given:** Connected to AirPlay, Chromecast, or other supported device.
- **When:** Taps "Cast" and selects device.
- **Then:** Audio/video streams to the chosen device.

### Rating and Reviewing Podcasts
- **Given:** Viewing podcast details.
- **When:** Submits rating/review.
- **Then:** Review is visible to others.

### Sharing Podcasts or Episodes
- **Given:** Viewing podcast/episode.
- **When:** Taps "Share" and selects method.
- **Then:** Content is shared using iOS share sheet.

### Sharing Audio Clips
- **Given:** User wants to share a segment of an episode.
- **When:** User selects a time range and shares audio clip.
- **Then:** Only the selected segment is shared.

### Podcast Addict API Integration (iOS Shortcuts, Google Assistant)
- **Given:** User has external automation apps (e.g., iOS Shortcuts, Google Assistant).
- **When:** Enables API integration in settings.
- **Then:** External apps can trigger actions (e.g., subscribe, play, update) via Podcast Addict's automation support.

### Accessing Error Reports and Logs
- **Given:** Wants to report issue.
- **When:** Uses "Report a bug"/"Send logs".
- **Then:** App compiles and sends info.

### Accessing Playback History
- **Given:** Has played episodes.
- **When:** Views "History".
- **Then:** Chronological list shown; can revisit episodes.

### Exporting User Data
- **Given:** Wants to back up/transfer data.
- **When:** Uses "Backup/Restore" or "Export Data".
- **Then:** Data file generated for saving/sharing.

### Playback Progress Sync (Clarification)
- **Given:** User has cloud backup enabled.
- **When:** User plays episodes on one device.
- **Then:** Progress is synced across devices.

### Apple Watch Support
- **Given:** User has an Apple Watch paired with their iPhone.
- **When:** Opens the Podcast Addict app on Apple Watch.
- **Then:** Can access advanced controls and quick actions (bookmark, archive, share, etc.).

### OPML Export
- **Given:** User wants to back up or migrate podcast subscriptions.
- **When:** Selects "Export OPML" in settings.
- **Then:** App generates and saves an OPML file containing all subscriptions.

### Smart Recommendations
- **Given:** User has a listening history in the app.
- **When:** Navigates to the recommendations section or receives a suggestion.
- **Then:** App displays advanced personalized recommendations based on history and preferences.

### Parental Controls and Content Filters
- **Given:** User wants to restrict explicit content or set parental controls for advanced features.
- **When:** Enables parental controls or sets content filters in settings.
- **Then:** Explicit content is hidden or restricted according to preferences.

### Apple ID Sign-In and iCloud Sync
- **Given:** User wants to sync advanced settings across devices.
- **When:** Signs in with Apple ID and enables iCloud sync.
- **Then:** Advanced settings are synced automatically across all devices.

### In-App Help and Support
- **Given:** User needs help or wants to provide feedback.
- **When:** Accesses the help/support section in the app.
- **Then:** Can view FAQ, contact support, and submit feedback directly.

### Accessibility for Advanced Features
- **Given:** User has accessibility needs (e.g., uses VoiceOver, prefers large text, needs high contrast).
- **When:** Uses advanced features in the app.
- **Then:** All controls and features are fully compatible with VoiceOver, Dynamic Type, and high-contrast color schemes.
