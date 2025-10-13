# Integration Test Summary

## Suites
- `CoreWorkflowIntegrationTests.swift`
  - **Purpose**: Exercises the end-to-end content workflows from subscription through playback and organization (Issues `02.1`, `02.1.3`, `02.1.5`).
  - **Highlights**: Validates folder/tag hierarchies, queue management, and search indexing against shared managers.
  - **Gaps**: Playback controls still rely on unit coverage; download queue orchestration pending Issue 04.1.
- `SimpleCoreIntegrationTests.swift`
  - **Purpose**: Smoke-test cross-package data flows for podcast, folder, and search coordination.
  - **Highlights**: Confirms CoreModels/TestSupport helpers interoperate when composed without UI glue.
  - **Gaps**: Does not persist data across launches; primarily sanity coverage for shared utilities.
- `SwipeConfigurationIntegrationTests.swift`
  - **Purpose**: Maps to Issue `02.1.6.3` acceptance criterion 2 (spec `ui.md`, Scenario 6) ensuring swipe settings persist across relaunches via the modular service.
  - **Highlights**: Verifies `SettingsManager.updateGlobalUISettings` delegates to `SwipeConfigurationService` and that a new manager instance hydates the saved configuration.
  - **Gaps**: Download and playback preset migrations will require follow-up coverage once their modular paths land (Issue 02.1.6.4).

## Open Questions
- Need macOS/Xcode environment to execute SettingsDomain SwiftPM tests referenced by these suites; current Linux CI leg only performs syntax checks.
- Future registry features (appearance, notifications, downloads) should gain mirrored integration tests after service migrations stabilize.
