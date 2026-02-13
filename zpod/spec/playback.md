# Podcast Playback Control

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Core Playback Behavior](#core-playback-behavior)
  - [Starting Episode Playback](#starting-episode-playback)
  - [Timeline Advancement During Playback](#timeline-advancement-during-playback)
  - [Pausing Playback](#pausing-playback)
  - [Resuming Playback](#resuming-playback)
  - [Seeking to Position](#seeking-to-position)
  - [Background Playback](#background-playback)
  - [Audio Interruption Handling](#audio-interruption-handling)
  - [Headphone Disconnect](#headphone-disconnect)
- [Playback Error Handling](#playback-error-handling)
  - [Episode Missing Audio URL](#episode-missing-audio-url)
  - [Network Error During Playback](#network-error-during-playback)
  - [Successful Retry After Error](#successful-retry-after-error)
- [Playing an Episode with Custom Speed](#playing-an-episode-with-custom-speed)
- [Skipping Silences and Boosting Volume](#skipping-silences-and-boosting-volume)
- [Skip Silence: Custom Threshold](#skip-silence-custom-threshold)
- [Using the Sleep Timer](#using-the-sleep-timer)
- [Sleep Timer: Shake to Reset](#sleep-timer-shake-to-reset)
- [Setting Alarms for Podcasts (iOS Notification/Reminders)](#setting-alarms-for-podcasts-ios-notificationreminders)
- [Navigating Episode Chapters](#navigating-episode-chapters)
- [Enhanced Transcript View](#enhanced-transcript-view)
- [Automatically Skipping Intro/Outro Segments](#automatically-skipping-introoutro-segments)
- [Custom Skip Intervals](#custom-skip-intervals)
- [AirPlay and Control Center Integration](#airplay-and-control-center-integration)
- [Using Explicit Rewind/Fast-Forward Buttons](#using-explicit-rewindfast-forward-buttons)
- [Enabling Shuffle Playback](#enabling-shuffle-playback)
- [Manually Marking Episodes as Played/Unplayed](#manually-marking-episodes-as-playedunplayed)
- [Adjusting In-App Volume Control](#adjusting-in-app-volume-control)
- [Controlling Video Playback Options](#controlling-video-playback-options)
- [Adding Episode Notes (Missing Feature)](#adding-episode-notes-missing-feature)
- [Apple Watch Support](#apple-watch-support)
- [Notification Actions](#notification-actions)
- [Siri and Shortcuts Integration](#siri-and-shortcuts-integration)
- [Smart Episode Management](#smart-episode-management)
- [Custom Notification Sounds Per Podcast](#custom-notification-sounds-per-podcast)
- [Advanced Search](#advanced-search)
- [Parental Controls and Content Filters](#parental-controls-and-content-filters)
- [Accessibility for Playback Features](#accessibility-for-playback-features)

**Description:** Users have extensive control over episode playback, including speed, effects, and timers, designed for iPhone/iOS conventions.

## Background
- **Given:** The app is launched on iPhone.
- **And:** At least one episode is available.

## Core Playback Behavior

These scenarios define fundamental playback behaviors that form the foundation for all other playback features.

### Starting Episode Playback
- **Given:** User has selected an episode with a valid audio URL.
- **When:** User taps the play button.
- **Then:** Audio begins streaming through the device speakers.
- **And:** The playback position starts at 0 (or last saved position if resuming).
- **And:** The Now Playing info updates with episode metadata.

### Timeline Advancement During Playback
- **Given:** An episode is currently playing.
- **When:** 1 second of real time passes.
- **Then:** The displayed playback position increases by 1 second.
- **And:** The progress bar advances proportionally.
- **And:** The lock screen/Control Center position updates.

### Pausing Playback
- **Given:** An episode is currently playing at position X.
- **When:** User taps the pause button.
- **Then:** Audio output stops.
- **And:** The playback position remains at X.
- **And:** The progress bar stops advancing.

### Resuming Playback
- **Given:** An episode is paused at position X.
- **When:** User taps the play button.
- **Then:** Audio resumes from position X.
- **And:** The timeline continues advancing.

### Seeking to Position
- **Given:** An episode is playing or paused.
- **When:** User drags the scrubber to position Y.
- **Then:** Playback position jumps to Y.
- **And:** Audio resumes from position Y (if playing).

### Background Playback
- **Given:** An episode is playing.
- **When:** User backgrounds the app or locks the device.
- **Then:** Audio continues playing.
- **And:** Lock screen controls remain functional.
- **And:** Position continues advancing.

### Audio Interruption Handling
- **Given:** An episode is playing.
- **When:** A phone call is received.
- **Then:** Playback pauses automatically.
- **And:** When the call ends, playback may resume per system settings.

### Headphone Disconnect
- **Given:** An episode is playing via headphones.
- **When:** Headphones are unplugged.
- **Then:** Playback pauses immediately.
- **And:** User must manually resume.

---

## Playback Error Handling

These scenarios define how the app handles playback failures gracefully.

### Episode Missing Audio URL
- **Given:** User selects an episode with no audioURL.
- **When:** User attempts to play the episode.
- **Then:** An error message displays "This episode doesn't have audio available".
- **And:** No retry button is shown.
- **And:** The error is logged for diagnostics.

### Network Error During Playback
- **Given:** User selects an episode with a valid audio URL.
- **When:** Playback fails due to network unavailability.
- **Then:** An error message displays "Unable to load episode. Check your connection."
- **And:** A retry button is shown.
- **And:** Tapping retry attempts playback again.

### Successful Retry After Error
- **Given:** Playback previously failed with a recoverable error.
- **When:** User taps retry.
- **And:** The issue is resolved (network restored).
- **Then:** Playback begins successfully.
- **And:** The error state clears.

---

## Advanced Playback Features

### Playing an Episode with Custom Speed
- **Given:** On episode playback screen.
- **When:** Adjusts "Playback speed" (0.8x–5.0x).
- **Then:** Audio speed changes; can apply globally or per podcast.

### Skipping Silences and Boosting Volume
- **Given:** Episode is playing.
- **When:** Enables "Skip silence" or "Volume boost"/"Mono audio".
- **Then:** Silences are skipped; audio is processed.

### Skip Silence: Custom Threshold
- **Given:** Episode is playing.
- **When:** User adjusts silence detection threshold in playback settings.
- **Then:** App skips silences based on user-defined sensitivity.

### Using the Sleep Timer
- **Given:** Episode is playing.
- **When:** Activates "Sleep timer" and sets duration.
- **Then:** Playback stops after timer or episode ends.

### Sleep Timer: Shake to Reset
- **Given:** Sleep timer is active during playback.
- **When:** User shakes the device.
- **Then:** Sleep timer resets to its original duration.

### Setting Alarms for Podcasts (iOS Notification/Reminders)
- **Given:** User wants a podcast as an alarm.
- **When:** Configures alarm (time, days, content) using iOS notifications or Reminders integration.
- **Then:** App plays selected content at set time.

### Navigating Episode Chapters
- **Given:** Episode has chapters.
- **When:** Selects a chapter.
- **Then:** Playback jumps to chapter start.

### Enhanced Transcript View
- **Given:** Episode has transcript.
- **When:** Accesses "Transcript View".
- **Then:** Transcript displays; can tap to jump playback.

### Automatically Skipping Intro/Outro Segments
- **Given:** Listening to an episode.
- **When:** Defines intro/outro skip durations.
- **Then:** App skips those segments automatically.

### Custom Skip Intervals
- **Given:** User wants to set custom skip intervals for rewind/fast-forward.
- **When:** User configures skip intervals in settings.
- **Then:** Playback buttons skip by user-defined intervals.

### AirPlay and Control Center Integration
- **Given:** Episode is playing.
- **When:** User opens Control Center or AirPlay menu.
- **Then:** Playback controls and device streaming are available.

### Using Explicit Rewind/Fast-Forward Buttons
- **Given:** Episode is playing.
- **When:** Taps "Rewind"/"Fast-Forward".
- **Then:** Playback skips by configurable interval.

### Enabling Shuffle Playback
- **Given:** Viewing a playlist/queue.
- **When:** Enables "Shuffle".
- **Then:** Episodes play in random order.

### Manually Marking Episodes as Played/Unplayed
- **Given:** Viewing episode list.
- **When:** Marks episode as played/unplayed.
- **Then:** Status updates and affects filters/tracking.

### Adjusting In-App Volume Control
- **Given:** Episode is playing.
- **When:** Adjusts volume in app.
- **Then:** Only app audio output changes.

### Controlling Video Playback Options
- **Given:** Playing a video episode.
- **When:** Accesses video controls.
- **Then:** Can toggle full-screen, select quality, use PiP.

### Adding Episode Notes (Missing Feature)
- **Given:** User is viewing an episode.
- **When:** User adds notes or comments to the episode.
- **Then:** Notes are saved and accessible for future reference.

### Apple Watch Support
- **Given:** User has an Apple Watch paired with their iPhone.
- **When:** Opens the Podcast Addict app on Apple Watch.
- **Then:** Can control playback, view episode lists, and perform quick actions (play, pause, skip, mark as played).

### Notification Actions
- **Given:** User receives a podcast notification on iOS.
- **When:** Interacts with the notification.
- **Then:** Can play, skip, or mark episodes as played directly from the notification.

### Siri and Shortcuts Integration
- **Given:** User wants to control playback via voice or automation.
- **When:** Configures Siri or iOS Shortcuts for playback actions.
- **Then:** Can trigger playback actions (play latest, skip, rewind, etc.) via Siri or Shortcuts.
- **Given:** The app restarted after the user had episodes available offline and persisted their metadata.
- **When:** Siri is asked to "Play latest" immediately after launch (before any feed refresh).
- **Then:** Siri snapshots already contain the latest episode metadata so playback starts without requiring a network fetch.

### Smart Episode Management
- **Given:** User wants automated episode management.
- **When:** Enables auto-archive, auto-delete played, or smart cleanup rules in settings.
- **Then:** Episodes are managed automatically according to preferences.

### Custom Notification Sounds Per Podcast
- **Given:** User wants custom notification sounds for podcasts.
- **When:** Sets custom sound in notification settings for a podcast.
- **Then:** Notifications use the selected sound for that podcast.

### Advanced Search
- **Given:** User wants to search across all podcasts, episodes, and show notes.
- **When:** Uses unified search interface.
- **Then:** Results include podcasts, episodes, and show notes.

### Parental Controls and Content Filters
- **Given:** User wants to restrict explicit content or set parental controls.
- **When:** Enables parental controls or sets content filters in settings.
- **Then:** Explicit podcasts/episodes are hidden or restricted according to preferences.

### Accessibility for Playback Features
- **Given:** User has accessibility needs (e.g., uses VoiceOver, prefers large text, needs high contrast).
- **When:** Uses playback features in the app.
- **Then:** All controls and features are fully compatible with VoiceOver, Dynamic Type, and high-contrast color schemes.
