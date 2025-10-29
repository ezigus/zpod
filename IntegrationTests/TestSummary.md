# Integration Test Summary

## Suites

### Core Workflow Tests (Cross-Component)
- `CoreWorkflowIntegrationTests.swift` (260 lines)
  - **Purpose**: Cross-component data consistency and complete end-to-end user journey workflows.
  - **Highlights**: Validates data synchronization between podcast manager, folder manager, search index, episode state, and playlists.
  - **Spec Coverage**: Acceptance criteria tests covering complete user workflows across all domains.
  - **Decomposition**: Domain-specific tests extracted to focused suites (Issue 02.2.1).

### Domain-Specific Integration Tests  
- `SearchDiscoveryIntegrationTests.swift` (476 lines)
  - **Purpose**: Search and discovery workflows (Issue 01.1.1 scenarios).
  - **Highlights**: Complete search subscription workflow, advanced search across content, RSS feed URL addition, search performance and history.
  - **Spec Coverage**: `discovery.md` lines 36-120 (search, RSS feeds, browsing).

- `PlaylistPlaybackIntegrationTests.swift` (254 lines)
  - **Purpose**: Playlist creation and playback queue workflows.
  - **Highlights**: Manual and smart playlist functionality, playback queue generation, episode state integration with playlists.
  - **Spec Coverage**: `playback.md` lines 96-140 (queue management, shuffle, episode state).

- `OrganizationIntegrationTests.swift` (196 lines)
  - **Purpose**: Subscription and organization workflows.
  - **Highlights**: Complete subscription workflow, folder/tag hierarchies, multi-level organization, search integration with organized content.
  - **Spec Coverage**: `spec.md` lines 114-235 (organization, folders, tags).

### Shared Utilities
- `IntegrationTestSupport.swift` (221 lines)
  - **Purpose**: Common mocks and test utilities shared across integration test suites.
  - **Highlights**: MockEpisodeStateManager, MockRSSParser, PodcastIndexSource, EpisodeIndexSource, PlaylistManager, PlaylistEngine.
  - **Benefits**: Eliminates code duplication, provides consistent test infrastructure.

### Other Integration Tests
- `SimpleCoreIntegrationTests.swift` (135 lines)
  - **Purpose**: Smoke-test cross-package data flows for podcast, folder, and search coordination.
  - **Highlights**: Confirms CoreModels/TestSupport helpers interoperate when composed without UI glue.
  - **Gaps**: Does not persist data across launches; primarily sanity coverage for shared utilities.

- `SwipeConfigurationIntegrationTests.swift` (81 lines)
  - **Purpose**: Maps to Issue `02.1.6.3` acceptance criterion 2 (spec `ui.md`, Scenario 6) ensuring swipe settings persist across relaunches via the modular service.
  - **Highlights**: Verifies `SettingsManager.updateGlobalUISettings` delegates to `SwipeConfigurationService` and that a new manager instance hydrates the saved configuration.
  - **Gaps**: Download and playback preset migrations will require follow-up coverage once their modular paths land (Issue 02.1.6.4).

## Coverage Summary
- Total Integration Test Code: 1,623 lines across 7 Swift files (excludes TestSummary.md)
  - CoreWorkflowIntegrationTests: 260 lines
  - SearchDiscoveryIntegrationTests: 476 lines
  - PlaylistPlaybackIntegrationTests: 254 lines
  - OrganizationIntegrationTests: 196 lines
  - IntegrationTestSupport: 221 lines
  - SimpleCoreIntegrationTests: 135 lines (pre-existing)
  - SwipeConfigurationIntegrationTests: 81 lines (pre-existing)
- CoreWorkflowIntegrationTests reduced from 1,190 to 260 lines (78% reduction)
- All files now below SwiftLint type_body_length threshold (500 lines)
- No SwiftLint suppressions required

## Open Questions
- Need macOS/Xcode environment to execute SettingsDomain SwiftPM tests referenced by these suites; current Linux CI leg only performs syntax checks.
- Future registry features (appearance, notifications, downloads) should gain mirrored integration tests after service migrations stabilize.

