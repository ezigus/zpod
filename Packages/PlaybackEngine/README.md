# PlaybackEngine

Audio playback engine for podcast episodes with state management, transport controls, and actual audio streaming.

## Overview

The PlaybackEngine package provides components for managing podcast episode playback, including:

- **EnhancedEpisodePlayer**: Main playback coordinator with state management, chapter navigation, persistence, and business logic
- **AVPlayerPlaybackEngine** (iOS only): Actual audio streaming using AVPlayer
- **SimplePlaybackService**: Lightweight playback stub for cross-platform testing

## Architecture

### Two-Layer Design

```
┌─────────────────────────────────────┐
│ EnhancedEpisodePlayer               │  ← State Management & Business Logic
│ ├─ Chapter navigation               │
│ ├─ Playback speed                   │
│ ├─ Position persistence             │
│ ├─ Skip silence/boost flags         │
│ └─ Auto-finish detection            │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ AVPlayerPlaybackEngine (iOS)        │  ← Audio Streaming
│ ├─ AVPlayer for URL streaming       │
│ ├─ Time observer (0.5s updates)     │
│ ├─ Error detection (KVO)            │
│ └─ Rate control (playback speed)    │
└─────────────────────────────────────┘
```

### Integration Pattern

**Test Mode** (fast, deterministic, no audio):
```swift
let player = EnhancedEpisodePlayer(ticker: DeterministicTicker())
player.play(episode: testEpisode, duration: 60)
// Position updates from ticker, no audio output
```

**Production Mode** (iOS, real audio):
```swift
let audioEngine = AVPlayerPlaybackEngine()
let player = EnhancedEpisodePlayer(audioEngine: audioEngine)
player.play(episode: realEpisode, duration: 1800)
// Audio streams from episode.audioURL, position from AVPlayer
```

## Key Features

### EnhancedEpisodePlayer

- **State Management**: Publishes `EpisodePlaybackState` via Combine
- **Persistence**: Auto-saves position every 5 seconds via `EpisodeStateManager`
- **Chapters**: Automatic chapter generation or custom resolver
- **Transport Controls**: Play, pause, seek, skip forward/backward
- **Playback Speed**: 0.8x - 5.0x with live adjustment
- **Finish Detection**: Auto-marks episodes as played when reaching end
- **Feature Flags**: Skip silence, volume boost (UI-only, no implementation)

### AVPlayerPlaybackEngine (iOS Only)

- **Audio Streaming**: Plays from remote URLs via AVPlayer
- **Position Updates**: Emits position every 0.5s via callback
- **Error Detection**: Monitors player status for network/decoding failures
- **Seek Support**: Jump to any position in the stream
- **Rate Control**: Adjust playback speed (1.0 = normal, 2.0 = 2x)
- **Resource Management**: Clean observer removal in `stop()` and `deinit`

## Usage

### Basic Playback

```swift
import PlaybackEngine
import CoreModels

// Create player (production mode)
let audioEngine = AVPlayerPlaybackEngine()
let player = EnhancedEpisodePlayer(audioEngine: audioEngine)

// Play an episode
let episode = Episode(
    id: "ep-123",
    title: "Sample Episode",
    audioURL: URL(string: "https://example.com/episode.mp3"),
    duration: 1800
)
player.play(episode: episode, duration: 1800)

// Observe state changes
player.statePublisher
    .sink { state in
        switch state {
        case .playing(let ep, let position, let duration):
            print("Playing: \(ep.title) at \(position)s / \(duration)s")
        case .paused(let ep, let position, _):
            print("Paused: \(ep.title) at \(position)s")
        case .finished(let ep, _):
            print("Finished: \(ep.title)")
        case .failed(let ep, _, _, let error):
            print("Error playing \(ep.title): \(error)")
        case .idle:
            print("Idle")
        }
    }
    .store(in: &cancellables)
```

### Transport Controls

```swift
// Pause
player.pause()

// Seek to 5 minutes
player.seek(to: 300)

// Skip forward 30 seconds
player.skipForward(interval: 30)

// Skip backward 15 seconds
player.skipBackward(interval: 15)

// Change playback speed
player.setPlaybackSpeed(1.5)  // 1.5x speed
```

### Chapters

```swift
// Provide custom chapters
let player = EnhancedEpisodePlayer(
    audioEngine: audioEngine,
    chapterResolver: { episode, duration in
        return [
            Chapter(id: "ch1", title: "Introduction", startTime: 0, endTime: 120),
            Chapter(id: "ch2", title: "Main Content", startTime: 120, endTime: 1680),
            Chapter(id: "ch3", title: "Conclusion", startTime: 1680, endTime: 1800)
        ]
    }
)

// Navigate chapters
player.nextChapter()      // Jump to next chapter
player.previousChapter()  // Jump to previous chapter
player.jumpToChapter(chapters[1])  // Jump to specific chapter
```

## Error Handling

The engine handles several error scenarios:

1. **Episode Missing Audio URL**: Emits `.failed(.episodeUnavailable)` immediately
2. **Network Failure**: AVPlayer detects via KVO, emits `.failed(.streamFailed)`
3. **Invalid URL**: AVPlayer detects, emits `.failed(.streamFailed)`

Error states include position and duration for UI recovery:

```swift
case .failed(let episode, let position, let duration, let error):
    // Show error message
    // Optionally show retry button for .streamFailed
    // Resume at `position` if user retries
```

## Audio Session Integration

AVPlayerPlaybackEngine **does not** configure the audio session. It expects the session to be set up by `SystemMediaCoordinator`:

- Category: `.playback`
- Mode: `.spokenAudio`
- Options: `.allowAirPlay`, `.allowBluetooth`, `.allowBluetoothA2DP`

The engine only calls `AVAudioSession.sharedInstance().setActive(true)` when starting playback.

## Testing

### Unit Tests

- `AVPlayerPlaybackEngineTests.swift`: Tests AVPlayer integration (requires iOS/macOS)
- `EnhancedEpisodePlayerTickerTests.swift`: Tests ticker-based state management

### Integration Tests

- `EnhancedEpisodePlayerAudioIntegrationTests.swift`: Tests full audio playback flow (requires iOS/macOS)

### Test Strategy

**Fast Tests** (Linux CI):
```swift
let player = EnhancedEpisodePlayer(ticker: DeterministicTicker())
// Fast, deterministic, no audio hardware required
```

**Real Audio Tests** (iOS device):
```swift
let audioEngine = AVPlayerPlaybackEngine()
let player = EnhancedEpisodePlayer(audioEngine: audioEngine)
// Actual audio playback, network required
```

## Spec References

Implementation validates against `zpod/spec/playback.md`:

- ✅ Starting Episode Playback (lines 55-61)
- ✅ Timeline Advancement During Playback (lines 62-68)
- ✅ Pausing Playback (lines 69-75)
- ✅ Resuming Playback (lines 76-81)
- ✅ Seeking to Position (lines 82-87)
- ✅ Background Playback (lines 88-94)
- ✅ Audio Interruption Handling (lines 95-100)
- ✅ Headphone Disconnect (lines 101-106)
- ✅ Episode Missing Audio URL (lines 113-119)
- ✅ Network Error During Playback (lines 120-126)

## Dependencies

- **CoreModels**: Episode, Chapter types
- **SharedUtilities**: PlaybackError, Logger
- **CombineSupport**: Publishers for state observation
- **AVFoundation** (iOS only): AVPlayer, AVAudioSession

## Platform Support

- **iOS 18+**: Full audio playback support
- **macOS 14+**: Full audio playback support (AVPlayer available)
- **watchOS 11+**: Ticker-based simulation only (no AVPlayer)
- **Linux**: Ticker-based simulation only (no AVFoundation)

## Future Enhancements

- [ ] Queue support (AVQueuePlayer)
- [ ] Chapter metadata parsing from AVAsset
- [ ] AirPlay 2 multi-room support
- [ ] Remote control event handling
- [ ] Download and offline playback
- [ ] Variable speed pitch correction
- [ ] Skip silence implementation (audio processing)
- [ ] Volume boost implementation (audio processing)

## License

See LICENSE in repository root.
