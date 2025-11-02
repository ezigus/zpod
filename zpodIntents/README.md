# zpodIntents - Siri Integration Extension

This Intents Extension enables Siri voice control for zpod podcast playback, particularly in CarPlay contexts.

## Overview

The zpodIntents extension handles `INPlayMediaIntent` requests from Siri, allowing users to control podcast playback using natural language commands like:
- "Play the latest episode of [podcast name]"
- "Play [episode title]"
- "Continue playing [podcast]"

## Architecture

### Components

**IntentHandler.swift**
- Main entry point for the extension
- Routes intents to appropriate handlers

**PlayMediaIntentHandler.swift**
- Implements `INPlayMediaIntentHandling` protocol
- Resolves media search queries to specific episodes
- Triggers playback in main app via user activities

**Info.plist**
- Declares supported intent types
- Configures extension metadata

## How It Works

1. **User Voice Command**: User says "Hey Siri, play [episode/podcast]"
2. **Intent Resolution**: System creates `INPlayMediaIntent` and calls extension
3. **Media Search**: Extension searches for matching podcast/episode using fuzzy matching
4. **Disambiguation**: If multiple matches, Siri asks user to clarify
5. **Playback**: Extension returns `handleInApp` response with episode ID
6. **App Launch**: Main app receives user activity and starts playback

## Setup Requirements

### Xcode Project Configuration

1. Add Intents Extension target to zpod.xcodeproj
2. Set bundle ID: `us.zig.zpod.intents`
3. Enable Siri capability in main app target
4. Add NSExtension configuration to Info.plist

### Code Signing & Entitlements

Main app entitlements (zpod.entitlements):
```xml
<key>com.apple.developer.siri</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.us.zig.zpod</string>
</array>
```

Extension entitlements (zpodIntents.entitlements):
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.us.zig.zpod</string>
</array>
```

### Shared Data Access

The extension needs access to podcast/episode data. Options:

**Option 1: App Groups (Recommended)**
- Use shared UserDefaults or Core Data with app groups
- Both app and extension can access same data container

**Option 2: Shared Framework**
- Move data models to shared framework
- Link both app and extension to framework

## Media Donations

The main app donates playback activities to Siri using `INInteraction.donate()`. This enables:
- Personalized Siri suggestions based on listening history
- Siri Shortcuts for favorite podcasts
- "Continue listening" suggestions

Donations happen automatically when:
- User starts playing an episode
- User adds episode to queue from CarPlay

## Testing

### In Simulator
```bash
# Test with simulated Siri commands
xcrun simctl spawn booted log stream --predicate 'subsystem == "us.zig.zpod"' --level debug
```

### On Device
1. Enable Siri in Settings
2. Grant microphone permission to zpod
3. Connect to CarPlay (or use CarPlay simulator)
4. Test voice commands:
   - "Play [podcast name]"
   - "Play the latest episode of [podcast]"
   - "Continue playing podcasts"

### Unit Testing
```bash
./scripts/run-xcode-tests.sh -t zpodIntentsTests
```

## Troubleshooting

### Extension Not Loading
- Verify extension is embedded in main app bundle
- Check bundle IDs match expected pattern
- Ensure Info.plist declares INPlayMediaIntent

### No Search Results
- Verify app groups are configured correctly
- Check data is accessible from extension
- Add logging to searchMedia() method

### Siri Doesn't Recognize Commands
- Ensure microphone permission granted
- Check that media donations are being made
- Verify suggested invocation phrases are clear

## Future Enhancements

- [ ] Full podcast/episode data access via shared framework
- [ ] Advanced fuzzy matching with synonym support
- [ ] Playback queue voice commands ("Play my queue")
- [ ] Episode filtering by date/status ("Play unplayed episodes")
- [ ] Multi-language support

## References

- [SiriKit Media Intents](https://developer.apple.com/documentation/sirikit/media)
- [INPlayMediaIntent Documentation](https://developer.apple.com/documentation/sirikit/inplaymediaintent)
- [App Groups Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [Testing Intents](https://developer.apple.com/documentation/sirikit/testing_intents)
