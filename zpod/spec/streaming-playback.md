# Streaming Playback

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Core Streaming Behavior](#core-streaming-behavior)
  - [Starting Stream Playback](#starting-stream-playback)
  - [Buffering During Playback](#buffering-during-playback)
  - [Buffer Progress Indication](#buffer-progress-indication)
  - [Seeking While Streaming](#seeking-while-streaming)
- [Network Interruption Handling](#network-interruption-handling)
  - [Network Loss During Playback](#network-loss-during-playback)
  - [Network Recovery and Resume](#network-recovery-and-resume)
  - [Slow Network Buffering](#slow-network-buffering)
  - [Network Type Change (Wi-Fi to Cellular)](#network-type-change-wi-fi-to-cellular)
- [Streaming Performance](#streaming-performance)
  - [Initial Buffer Before Playback](#initial-buffer-before-playback)
  - [Adaptive Bitrate Streaming](#adaptive-bitrate-streaming)
  - [Preloading Next Episode](#preloading-next-episode)
- [Bandwidth Management](#bandwidth-management)
  - [Streaming Quality on Cellular](#streaming-quality-on-cellular)
  - [Streaming Quality on Wi-Fi](#streaming-quality-on-wi-fi)
  - [Bandwidth Estimation and Adjustment](#bandwidth-estimation-and-adjustment)
- [HTTP Range Request Support](#http-range-request-support)
  - [Seeking with Range Requests](#seeking-with-range-requests)
  - [Resume from Position](#resume-from-position)
- [Error Handling](#error-handling)
  - [Server Error (5xx)](#server-error-5xx)
  - [Not Found Error (404)](#not-found-error-404)
  - [Timeout During Streaming](#timeout-during-streaming)
  - [Automatic Retry on Transient Errors](#automatic-retry-on-transient-errors)

## Description
Users can stream podcast episodes directly from network sources without downloading, with intelligent buffering, network adaptation, and error recovery.

## Background
- **Given:** The app is launched on iPhone (iOS 18+).
- **And:** User is subscribed to at least one podcast.
- **And:** At least one episode with valid audioURL is available.
- **And:** Network connection is available.

## Core Streaming Behavior

### Starting Stream Playback
- **Given:** An episode is not downloaded.
- **And:** Network connection is available.
- **When:** User taps play on the episode.
- **Then:** App initiates HTTP request for audio URL.
- **And:** Initial buffer is loaded (target: 5 seconds of audio).
- **And:** Playback begins when initial buffer is ready.
- **And:** UI shows "Streaming" indicator.
- **And:** Buffer progress bar appears below timeline.

### Buffering During Playback
- **Given:** An episode is streaming.
- **When:** Playback is in progress.
- **Then:** App continuously buffers ahead of current position.
- **And:** Buffer maintains 15-30 seconds ahead when network is good.
- **And:** Buffer progress is visible in timeline UI.
- **And:** Playback continues smoothly without interruption.

### Buffer Progress Indication
- **Given:** An episode is streaming.
- **When:** User views the player interface.
- **Then:** Timeline shows two distinct bars:
  - Playback position (filled bar)
  - Buffered content (lighter overlay ahead of position)
- **And:** User can see how much content is buffered.

### Seeking While Streaming
- **Given:** An episode is streaming.
- **And:** User has buffered content ahead and behind current position.
- **When:** User seeks to a position within buffered range.
- **Then:** Playback jumps immediately to new position (within 100ms).
- **And:** No network request occurs.
- **When:** User seeks to a position outside buffered range.
- **Then:** App pauses briefly to buffer new position.
- **And:** HTTP range request is made for new position.
- **And:** Playback resumes when sufficient buffer is loaded.
- **And:** Seek completes within 2 seconds.

## Network Interruption Handling

### Network Loss During Playback
- **Given:** An episode is streaming.
- **And:** Playback has buffered content.
- **When:** Network connection is lost.
- **Then:** Playback continues using buffered audio.
- **And:** No error is shown while buffer remains.
- **When:** Buffer is exhausted.
- **Then:** Playback pauses automatically.
- **And:** UI shows "No Connection" indicator.
- **And:** Current position is preserved.

### Network Recovery and Resume
- **Given:** Streaming playback is paused due to network loss.
- **When:** Network connection is restored.
- **Then:** App automatically resumes buffering.
- **And:** Playback resumes when sufficient buffer is loaded.
- **And:** "No Connection" indicator is removed.
- **And:** Resume occurs within 3 seconds of connection restore.

### Slow Network Buffering
- **Given:** An episode is streaming on slow connection.
- **When:** Buffer is depleting faster than network can refill.
- **Then:** Playback pauses briefly to buffer.
- **And:** Loading spinner appears on play button.
- **And:** "Buffering..." indicator is shown.
- **When:** Sufficient buffer is restored.
- **Then:** Playback resumes automatically.
- **And:** No user interaction required.

### Network Type Change (Wi-Fi to Cellular)
- **Given:** An episode is streaming on Wi-Fi.
- **And:** User has "Stream on Cellular" enabled.
- **When:** Device switches to cellular connection.
- **Then:** Streaming continues without interruption.
- **And:** Quality may adjust based on cellular settings.
- **And:** No user intervention required.

## Streaming Performance

### Initial Buffer Before Playback
- **Given:** User starts streaming an episode.
- **When:** Initial HTTP request completes.
- **Then:** App buffers minimum 5 seconds of audio before playback.
- **And:** If network is fast (>1 Mbps), playback starts within 2 seconds.
- **And:** If network is slow (<500 Kbps), may buffer up to 10 seconds.
- **And:** Loading indicator shows buffer progress.

### Adaptive Bitrate Streaming
- **Given:** Podcast provides multiple quality streams (HLS/DASH).
- **When:** Network conditions change during playback.
- **Then:** App automatically selects appropriate quality tier.
- **And:** Switches occur seamlessly without stopping playback.
- **And:** Higher quality is selected on faster connections.
- **And:** Lower quality prevents buffering on slower connections.

### Preloading Next Episode
- **Given:** User is listening to an episode in a playlist.
- **And:** Current episode is nearing completion (last 2 minutes).
- **When:** Next episode is set to auto-play.
- **Then:** App begins preloading first 10 seconds of next episode.
- **And:** Transition between episodes is seamless (no gap).
- **And:** Preload occurs in background without affecting current playback.

## Bandwidth Management

### Streaming Quality on Cellular
- **Given:** User is streaming on cellular connection.
- **And:** "Cellular Streaming Quality" is set to "Low" (default).
- **When:** Episode begins streaming.
- **Then:** App requests lower bitrate version if available.
- **And:** Bandwidth usage is minimized.
- **And:** Audio quality is reduced but still acceptable.

### Streaming Quality on Wi-Fi
- **Given:** User is streaming on Wi-Fi connection.
- **When:** Episode begins streaming.
- **Then:** App requests highest quality version available.
- **And:** No bitrate limiting is applied.
- **And:** Fastest buffer fill rate is achieved.

### Bandwidth Estimation and Adjustment
- **Given:** An episode is streaming.
- **When:** App monitors network throughput.
- **Then:** Bandwidth estimate is updated every 5 seconds.
- **And:** Buffer strategy adjusts to network speed:
  - Fast network (>2 Mbps): Buffer 30 seconds ahead
  - Medium network (500 Kbps - 2 Mbps): Buffer 20 seconds ahead
  - Slow network (<500 Kbps): Buffer 10 seconds ahead
- **And:** Adjustments are transparent to user.

## HTTP Range Request Support

### Seeking with Range Requests
- **Given:** Podcast server supports HTTP Range requests (Accept-Ranges header).
- **And:** Episode is streaming.
- **When:** User seeks to a position far ahead of buffer.
- **Then:** App sends Range request for new position (e.g., `Range: bytes=1000000-`).
- **And:** Only requested portion is downloaded.
- **And:** No bandwidth is wasted downloading skipped content.

### Resume from Position
- **Given:** User previously paused streaming at 15:30 position.
- **And:** App was terminated.
- **When:** User resumes playback.
- **Then:** App sends Range request starting at saved position.
- **And:** Download resumes from correct byte offset.
- **And:** No audio before position is downloaded.

## Error Handling

### Server Error (5xx)
- **Given:** Episode is streaming.
- **When:** Server returns 500/502/503 error.
- **Then:** Playback pauses.
- **And:** Error alert shows "Server Error - Unable to stream".
- **And:** Retry button is presented.
- **And:** Automatic retry occurs after 5 seconds (up to 3 attempts).

### Not Found Error (404)
- **Given:** Episode has invalid or expired audioURL.
- **When:** App attempts to stream.
- **Then:** Error alert shows "Episode Not Available".
- **And:** No automatic retry occurs.
- **And:** User is prompted to refresh podcast feed.

### Timeout During Streaming
- **Given:** Episode is streaming.
- **When:** HTTP request times out (no data received for 30 seconds).
- **Then:** App treats as temporary network failure.
- **And:** Automatic retry occurs.
- **And:** UI shows "Connection timed out - Retrying...".

### Automatic Retry on Transient Errors
- **Given:** Streaming encounters temporary error (timeout, 503, connection reset).
- **When:** Error occurs.
- **Then:** App automatically retries up to 3 times.
- **And:** Retry delays: 2s, 5s, 10s (exponential backoff).
- **And:** Playback position is preserved across retries.
- **And:** After 3 failures, user is shown error and manual retry option.
