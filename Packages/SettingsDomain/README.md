# SettingsDomain

The SettingsDomain package owns the modular configuration infrastructure used across zPod. Each configurable surface supplies a service (persistence boundary), a controller (state + validation), and a feature descriptor that the settings registry uses to build the UI.

## Architecture
- **Services (`*ConfigurationService`)**: Actor-isolated adapters over `SettingsRepository`. They expose `load()`, `save(_:)`, and in most cases an async updates stream so SwiftUI surfaces can observe live changes.
- **Controllers (`*ConfigurationController`)**: `@MainActor` types that coordinate draft state, validation, and save/reset flows with their services. Controllers expose bindings for the UI layer and surface `hasUnsavedChanges`, `isSaving`, and baseline helpers used by tests.
- **Features (`*ConfigurationFeature`)**: Lightweight descriptors that provide metadata (id, title, icon, category) and vend controllers on demand. Features register with `FeatureConfigurationRegistry`, allowing the settings shell to discover all available modules without hard-coded switches.
- **Registry (`FeatureConfigurationRegistry`)**: Groups feature descriptors by category and resolves controllers asynchronously. `SettingsManager` owns a registry instance and populates it with the available features.

## Swipe Configuration Migration (Issue 02.1.6.3)
Swipe gestures now persist through `SwipeConfigurationService`, and legacy entry points (`SettingsManager.updateGlobalUISettings`) delegate to that service. This keeps all swipe persistence on the same asynchronous completion path while the modular settings UI loads controllers through the registry.

## Adding a New Feature Module
1. Define models in `CoreModels` / `Persistence` if needed, and extend `SettingsRepository` for load/save.
2. Implement a service conforming to the appropriate protocol (or a new one) inside SettingsDomain.
3. Create a controller that binds UI state to the service and write unit coverage for draft mutations and persistence flows.
4. Author a `ConfigurableFeature` descriptor that returns the controller and register it inside `SettingsManager.buildFeatureRegistry()`.
5. Update `SettingsFeatureRouteFactory` in `LibraryFeature` so the settings UI can render the new controller.
6. Add issue-linked docs/tests (dev log entry, target-specific `TestSummary.md` updates, and SwiftUI previews/UI tests as required).

## Testing
- Unit tests live under `Packages/SettingsDomain/Tests`, covering services, controllers, and registry helpers.
- Integration tests (`IntegrationTests/SwipeConfigurationIntegrationTests.swift`) exercise the modular save → relaunch → load path.
- UI coverage is located in `zpodUITests`, which waits on controllers to finish loading baselines before interacting with the UI.

## Follow-Up Work
- Issue 02.1.6.4 tracks preset automation and additional swipe workflows.
- Smart list automation, playback presets, notifications, appearance, and downloads already use the modular pipeline but still require macOS-hosted SwiftPM test runs.
- Future settings features must register through the registry and ship with matching documentation updates.
