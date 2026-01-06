# Offline Playback and Episode Download

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Core Download Behavior](#core-download-behavior)
  - [Manual Episode Download](#manual-episode-download)
  - [Download Progress Tracking](#download-progress-tracking)
  - [Download Completion](#download-completion)
  - [Download Cancellation](#download-cancellation)
  - [Download Failure Handling](#download-failure-handling)
- [Offline Playback](#offline-playback)
  - [Playing Downloaded Episode](#playing-downloaded-episode)
  - [Fallback to Streaming When Not Downloaded](#fallback-to-streaming-when-not-downloaded)
  - [Offline Indicator in UI](#offline-indicator-in-ui)
- [Storage Management](#storage-management)
  - [Downloaded Episodes Storage Location](#downloaded-episodes-storage-location)
  - [Storage Space Monitoring](#storage-space-monitoring)
  - [Manual Episode Deletion](#manual-episode-deletion)
  - [Bulk Episode Deletion](#bulk-episode-deletion)
- [Network Conditions](#network-conditions)
  - [Wi-Fi Only Download Setting](#wi-fi-only-download-setting)
  - [Cellular Download Warning](#cellular-download-warning)
  - [Download Resume After Network Loss](#download-resume-after-network-loss)
- [Audio Quality](#audio-quality)
  - [Download Quality Selection](#download-quality-selection)
  - [Quality Matches Source](#quality-matches-source)

## Description
Users can download podcast episodes to their device for offline playback, with controls for storage management, network conditions, and audio quality.

## Background
- **Given:** The app is launched on iPhone (iOS 18+).
- **And:** User is subscribed to at least one podcast.
- **And:** At least one episode is available.

## Core Download Behavior

### Manual Episode Download
- **Given:** User views an episode that is not downloaded.
- **When:** User taps the download button.
- **Then:** Episode begins downloading.
- **And:** Download button changes to show progress indicator.
- **And:** Episode appears in "Downloaded" section when complete.

### Download Progress Tracking
- **Given:** An episode is downloading.
- **When:** User views the episode in any list.
- **Then:** Progress indicator shows percentage downloaded.
- **And:** Estimated time remaining is displayed.
- **And:** Download can be tapped to view details.

### Download Completion
- **Given:** An episode is downloading.
- **When:** Download completes successfully.
- **Then:** Progress indicator changes to "Downloaded" badge.
- **And:** Notification is shown (if enabled).
- **And:** Episode is immediately available for offline playback.

### Download Cancellation
- **Given:** An episode is currently downloading.
- **When:** User taps cancel on the download.
- **Then:** Download stops immediately.
- **And:** Partial download data is removed.
- **And:** Download button returns to initial state.

### Download Failure Handling
- **Given:** An episode download fails (network error, storage full, etc.).
- **When:** Failure occurs.
- **Then:** User sees error notification with specific reason.
- **And:** Download button shows "Retry" option.
- **And:** User can tap to retry download.

## Offline Playback

### Playing Downloaded Episode
- **Given:** An episode is fully downloaded.
- **When:** User taps play on the episode.
- **Then:** Episode plays from local storage.
- **And:** No network request is made for audio data.
- **And:** Playback starts within 500ms (no buffering delay).
- **And:** UI shows "Downloaded" indicator during playback.

### Fallback to Streaming When Not Downloaded
- **Given:** An episode is not downloaded.
- **And:** Network connection is available.
- **When:** User taps play on the episode.
- **Then:** Episode streams from network URL.
- **And:** UI shows "Streaming" indicator.
- **And:** Buffer progress is displayed.

### Offline Indicator in UI
- **Given:** User is browsing episodes.
- **When:** Viewing episode list or details.
- **Then:** Downloaded episodes show clear "Downloaded" badge.
- **And:** Non-downloaded episodes show file size.
- **And:** Currently downloading episodes show progress.

## Storage Management

### Downloaded Episodes Storage Location
- **Given:** Episodes are downloaded.
- **When:** App stores downloaded audio files.
- **Then:** Files are stored in app's Documents directory.
- **And:** Files are organized by podcast/episode ID.
- **And:** File names are sanitized and consistent.

### Storage Space Monitoring
- **Given:** User has downloaded episodes.
- **When:** User views Settings > Storage.
- **Then:** Total storage used by downloads is displayed.
- **And:** Per-podcast storage breakdown is shown.
- **And:** Device storage remaining is indicated.

### Manual Episode Deletion
- **Given:** An episode is downloaded.
- **When:** User swipes episode and taps "Delete Download".
- **Then:** Downloaded file is removed from storage.
- **And:** Storage space is immediately freed.
- **And:** Episode reverts to "Download" button state.
- **And:** Playback position is preserved.

### Bulk Episode Deletion
- **Given:** Multiple episodes are downloaded.
- **When:** User selects "Delete All Downloads" for a podcast.
- **Then:** All downloaded episodes for that podcast are removed.
- **And:** Storage is freed.
- **And:** Confirmation dialog is shown before deletion.

## Network Conditions

### Wi-Fi Only Download Setting
- **Given:** User has enabled "Wi-Fi Only Downloads" in settings.
- **And:** User is on cellular connection.
- **When:** User attempts to download an episode.
- **Then:** Download is queued but not started.
- **And:** Message indicates "Waiting for Wi-Fi".
- **And:** Download begins automatically when Wi-Fi connects.

### Cellular Download Warning
- **Given:** User has "Warn on Cellular Download" enabled.
- **And:** User is on cellular connection.
- **When:** User taps download button.
- **Then:** Alert dialog warns about cellular data usage.
- **And:** User can confirm or cancel download.
- **And:** Choice is remembered for session if user selects "Don't Ask Again".

### Download Resume After Network Loss
- **Given:** An episode is downloading.
- **When:** Network connection is lost mid-download.
- **Then:** Download pauses automatically.
- **And:** UI shows "Paused - No Connection".
- **When:** Network connection is restored.
- **Then:** Download resumes from last byte received.
- **And:** No data is re-downloaded.

## Audio Quality

### Download Quality Selection
- **Given:** User is configuring download settings.
- **When:** User views "Download Quality" setting.
- **Then:** Options include "High", "Medium", "Low", "Match Source".
- **And:** File size estimates are shown for each quality.
- **And:** Default is "Match Source".

### Quality Matches Source
- **Given:** Download quality is set to "Match Source".
- **When:** User downloads an episode.
- **Then:** Downloaded file matches original podcast feed quality.
- **And:** No transcoding occurs.
- **And:** Download is fastest option.
