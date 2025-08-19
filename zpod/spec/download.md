# Download and Sync Management

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Automatic Episode Download](#automatic-episode-download)
- [Download Scheduler](#download-scheduler)
- [Managing Storage and Cleanup](#managing-storage-and-cleanup)
- [Granular Retention Policies](#granular-retention-policies)
- [Syncing Data to Cloud (iCloud, Google Drive, Dropbox, etc.)](#syncing-data-to-cloud-icloud-google-drive-dropbox-etc)
- [Syncing Download/Playback Progress](#syncing-downloadplayback-progress)
- [Casting to External Devices (AirPlay, Chromecast)](#casting-to-external-devices-airplay-chromecast)
- [Prioritizing Downloads](#prioritizing-downloads)
- [Setting Download Conditions](#setting-download-conditions)
- [Per-Podcast Wi-Fi Only Download](#per-podcast-wi-fi-only-download)
- [Handling Failed Downloads](#handling-failed-downloads)
- [Automatic Download Retry](#automatic-download-retry)
- [AirDrop Support for Sharing Downloads](#airdrop-support-for-sharing-downloads)
- [Apple ID Sign-In and iCloud Sync](#apple-id-sign-in-and-icloud-sync)
- [Smart Episode Management](#smart-episode-management)
- [OPML Export](#opml-export)
- [Parental Controls and Content Filters](#parental-controls-and-content-filters)
- [Notification Actions](#notification-actions)
- [Accessibility for Download Features](#accessibility-for-download-features)

**Description:** Robust options for downloading, managing, and syncing episodes, designed for iPhone/iOS conventions. Users can choose from available integrations for backup, sync, and casting (e.g., iCloud, Google Drive, Dropbox, AirPlay, Chromecast).

## Background
- **Given:** App is launched on iPhone.
- **And:** Active internet connection.

## Scenarios

### Automatic Episode Download
- **Given:** Subscribed to podcasts; "Automatic Download" enabled.
- **When:** New episode is available.
- **Then:** App downloads episode and adds to playlist if enabled.

### Download Scheduler
- **Given:** User wants to schedule downloads for specific times (e.g., overnight).
- **When:** User sets download schedule in settings.
- **Then:** App downloads episodes only during scheduled times.

### Managing Storage and Cleanup
- **Given:** Downloaded episodes.
- **When:** Configures "Storage folder" and "Automatic cleanup".
- **Then:** New downloads use folder; cleanup rules applied.

### Granular Retention Policies
- **Given:** User wants to control episode retention per podcast.
- **When:** User sets rules (e.g., keep X episodes, delete after X days, keep unplayed only).
- **Then:** App deletes episodes according to these rules.

### Syncing Data to Cloud (iCloud, Google Drive, Dropbox, etc.)
- **Given:** Active cloud account (iCloud, Google Drive, Dropbox, etc.).
- **When:** Enables "Cloud Backup".
- **Then:** Data is backed up and synced across devices using the selected service.

### Syncing Download/Playback Progress
- **Given:** User has cloud backup enabled.
- **When:** User plays or downloads episodes on one device.
- **Then:** Progress and downloads are synced across devices via the selected cloud service.

### Casting to External Devices (AirPlay, Chromecast)
- **Given:** Connected to AirPlay, Chromecast, or other supported device.
- **When:** Taps "Cast" and selects device.
- **Then:** Audio/video streams to the chosen device.

### Prioritizing Downloads
- **Given:** Multiple pending downloads.
- **When:** Reorders queue or sets priority.
- **Then:** Downloads follow specified order.

### Setting Download Conditions
- **Given:** Wants to control download timing.
- **When:** Configures "Download Conditions".
- **Then:** Downloads only occur under specified conditions.

### Per-Podcast Wi-Fi Only Download
- **Given:** User wants to restrict downloads to Wi-Fi for specific podcasts.
- **When:** User sets Wi-Fi only for a podcast.
- **Then:** App downloads episodes for that podcast only on Wi-Fi.

### Handling Failed Downloads
- **Given:** Download fails.
- **Then:** App shows notification and allows retry.

### Automatic Download Retry
- **Given:** Download fails.
- **When:** App attempts automatic retry based on user settings.
- **Then:** Download is retried until successful or user cancels.

### AirDrop Support for Sharing Downloads
- **Given:** User wants to share downloaded episodes.
- **When:** Uses AirDrop.
- **Then:** Episode files are sent to another iOS device.

### Apple ID Sign-In and iCloud Sync
- **Given:** User wants to sync downloads, settings, and progress across devices.
- **When:** Signs in with Apple ID and enables iCloud sync.
- **Then:** Downloads, settings, and progress are synced automatically across all devices.

### Smart Episode Management
- **Given:** User wants automated download management.
- **When:** Enables auto-archive, auto-delete played, or smart cleanup rules in settings.
- **Then:** Downloaded episodes are managed automatically according to preferences.

### OPML Export
- **Given:** User wants to back up or migrate podcast subscriptions.
- **When:** Selects "Export OPML" in settings.
- **Then:** App generates and saves an OPML file containing all subscriptions.

### Parental Controls and Content Filters
- **Given:** User wants to restrict explicit content or set parental controls.
- **When:** Enables parental controls or sets content filters in settings.
- **Then:** Explicit podcasts/episodes are hidden or restricted according to preferences.

### Notification Actions
- **Given:** User receives a download notification on iOS.
- **When:** Interacts with the notification.
- **Then:** Can pause, resume, or retry downloads directly from the notification.

### Accessibility for Download Features
- **Given:** User has accessibility needs (e.g., uses VoiceOver, prefers large text, needs high contrast).
- **When:** Uses download features in the app.
- **Then:** All controls and features are fully compatible with VoiceOver, Dynamic Type, and high-contrast color schemes.
