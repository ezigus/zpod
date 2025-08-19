# zPod

## Purpose
zPod is a mobile application project focused on delivering a seamless podcast experience for iPhone, Apple Watch, and CarPlay users. The app is written specifically for these platforms.

## Developer Instructions
**Note for Developers:** When writing code for this application, ensure that all features, UI, and logic are designed for iPhone (iOS), Apple Watch (watchOS), and CarPlay.

## Environment Setup
This project is designed to be developed in Visual Studio Code (VS Code) with a focus on Swift and iOS development. The following steps will help you set up your environment:


### Prerequisites
- Install the latest version of [VS Code](https://code.visualstudio.com/)
- **Install Xcode**: Xcode is required outside of VS Code for several reasons:
  - It provides the iOS, watchOS, and CarPlay simulators for testing your app on virtual devices.
  - It is necessary for building, signing, and deploying your app to physical devices.
  - Xcode includes essential SDKs, developer tools, and device management features that are not available in VS Code.
  - Some extensions in VS Code rely on Xcode being installed to enable debugging, running, and building Swift/iOS projects.

Without Xcode, you will not be able to fully develop, test, or distribute your iPhone, Apple Watch, or CarPlay applications.

### Recommended VS Code Extensions
Install these extensions for the best development experience:

- **Swift for Visual Studio Code** (`kiadstudios.vscode-swift`): Rich language support for Swift projects.
- **SweetPad (iOS/Swift development)** (`sweetpad.sweetpad`): Tools for Swift/iOS development.
- **Xcode iOS Swift IDE** (`fireplusteam.vscode-ios`): Develop Swift iOS applications in VS Code like in Xcode.
- **SwiftUI** (`fenkinet.swiftui`): Basic support for SwiftUI in VS Code.
- **Syntax Xcode Project Data** (`mariomatheu.syntax-project-pbxproj`): Syntax highlight for Xcode project files.
- **Xcode strings** (`mhcpnl.xcodestrings`): Highlighting for Xcode .strings files.
- **Swift Development** (`alishobeiri.swift-development`): Complete Swift development support including simulator and debug.

You can install these extensions from the VS Code Extensions Marketplace.

### Getting Started
1. Clone the repository:
   ```sh
   git clone https://github.com/ezigus/zpodcastaddict.git
   ```
2. Open the project folder in VS Code.
3. Install the recommended extensions listed above.
4. Use Xcode for running simulators and deploying to devices as needed.

## Target Platforms


## Subscription Architecture (Issue 01 Summary)
Core flow for adding a podcast by RSS feed URL (implemented in Issue 01):
1. `SubscriptionService.subscribe(feedURLString:)` validates URL (http/https only) and requests raw feed data via an injected `FeedDataLoading` dependency (mocked in tests; networking deferred).
2. Raw XML is parsed by `RSSFeedParser` (pull-based `XMLParser`) into a `ParsedFeed` containing a `Podcast` plus its initial `[Episode]` list. Parser resets internal state each parse invocation to avoid cross-feed contamination.
3. `SubscriptionService` persists the resulting `Podcast` (with episodes attached) through a future `PodcastManaging` abstraction (currently planned / in-memory placeholder) marking `isSubscribed = true` and stamping `dateAdded`.
4. Duplicate subscriptions (same feed URL / podcast id) surface a `duplicateSubscription` error; invalid URLs, data retrieval, or parse errors map to dedicated error cases.

Key types:
- `SubscriptionService`: Orchestrates subscription lifecycle & error handling.
- `FeedDataLoading`: Protocol enabling testable feed data injection.
- `FeedParsing` (`RSSFeedParser`): Extracts channel + item metadata (title, description, author, artwork URL, categories, episode GUID/enclosure URL & title, optional mediaURL).
- `Episode`: Extended to include optional `mediaURL` to support future download & playback tasks.

Planned Extensions (future issues): update frequency service, OPML import/export, download manager integration, and real persistence layer.

- macOS
- iPadOS
- tvOS

**Note:** All development and testing should focus on the supported devices listed above.

---
For any questions or issues, please open an issue in the repository.
