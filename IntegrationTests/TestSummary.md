# Integration Test Summary

## Suites

### Core Workflow Tests (Cross-Component)
- `CoreWorkflowIntegrationTests.swift` (261 lines)
  - **Purpose**: Cross-component data consistency and end-to-end user workflow coverage.
  - **Highlights**: Validates data synchronization between podcast manager, folder manager, search index, episode state, and playlists.
  - **Spec Coverage**: Acceptance criteria tests covering complete user workflows across domains.
  - **Decomposition**: Domain-specific suites extracted (Issue 02.2.1).

- `PlaybackStateSynchronizationIntegrationTests.swift` (616 lines)
  - **Purpose**: Playback state propagation across playback engine, UI, and persistence.
  - **Highlights**: Verifies state updates, timing, and handoffs remain consistent across modules.
  - **Spec Coverage**: `playback.md` scenarios covering playback state behavior.

- `SwipeActionsEpisodeListIntegrationTests.swift` (143 lines)
  - **Purpose**: Episode list swipe action integration and state propagation.
  - **Highlights**: Validates swipe actions route through shared services and persist expected state.
  - **Spec Coverage**: `ui.md` swipe interactions and episode list management scenarios.

### Domain-Specific Integration Tests
- `SearchDiscoveryIntegrationTests.swift` (475 lines)
  - **Purpose**: Search and discovery workflows (Issue 01.1.1 scenarios).
  - **Highlights**: Complete search subscription workflow, advanced search across content, RSS feed URL addition, search performance and history.
  - **Spec Coverage**: `discovery.md` scenarios (search, RSS feeds, browsing).

- `PlaylistPlaybackIntegrationTests.swift` (256 lines)
  - **Purpose**: Playlist creation and playback queue workflows.
  - **Highlights**: Manual and smart playlist functionality, playback queue generation, episode state integration with playlists.
  - **Spec Coverage**: `playback.md` scenarios (queue management, shuffle, episode state).

- `OrganizationIntegrationTests.swift` (194 lines)
  - **Purpose**: Subscription and organization workflows.
  - **Highlights**: Folder/tag hierarchies, multi-level organization, search integration with organized content.
  - **Spec Coverage**: `spec.md` and `customization.md` organization scenarios.

- `PodcastPersistenceIntegrationTests.swift` (376 lines)
  - **Purpose**: SwiftData-backed podcast persistence across app restarts (Issue 27.1).
  - **Highlights**: Persistence across container recreation, in-memory isolation, organization persistence.
  - **Spec Coverage**: `discovery.md` and `customization.md` persistence scenarios.

- `SwipeConfigurationIntegrationTests.swift` (81 lines)
  - **Purpose**: Swipe configuration persistence via SettingsDomain services.
  - **Highlights**: Validates swipe settings are persisted and rehydrated.
  - **Spec Coverage**: `ui.md` swipe configuration scenarios (Issue 02.1.6.3).

### Other Integration Tests
- `SimpleCoreIntegrationTests.swift` (140 lines)
  - **Purpose**: Smoke-test cross-package data flows without UI glue.
  - **Highlights**: Confirms CoreModels/TestSupport helpers interoperate when composed.
  - **Gaps**: Does not persist data across launches; primarily sanity coverage.

### Shared Utilities
- `IntegrationTestSupport.swift` (58 lines)
  - **Purpose**: Common mocks and utilities shared across integration suites.
  - **Highlights**: Mock episode state, podcast index sources, playlist helpers.

- `WorkflowTestBuilder.swift` (174 lines)
  - **Purpose**: Builder for end-to-end workflow test setup.

- `SearchTestBuilder.swift` (97 lines)
  - **Purpose**: Search flow setup and fixture helpers.

- `MockRSSParser.swift` (35 lines)
  - **Purpose**: Predictable RSS parsing fixture for integration tests.

## Coverage Summary
- Total Integration Test Code: 2,906 lines across 13 Swift files (excludes TestSummary.md)
- No SwiftLint suppressions required for integration test files

## Open Questions
- Need macOS/Xcode environment to execute SettingsDomain SwiftPM tests referenced by these suites; current Linux CI leg only performs syntax checks.
