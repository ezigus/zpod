# Test Summary – AppSmokeTests

The `AppSmokeTests` target provides a thin smoke layer to ensure the `zpodLib` umbrella module
exposes the expected cross-package APIs.

## Coverage
- Confirms CoreModels types (e.g. `Podcast`) are reachable via `zpodLib` re-exports.
- Verifies SharedUtilities helpers are accessible and behave as expected (`SharedError`).
- Exercises `SwiftDataPodcastRepository` CRUD, organization queries, and Siri refresh hooks (Issue 27.1).

## Gaps
- All behavioural tests live in the individual package test suites.
- UI coverage is provided by `zpodUITests`.
- Integrated workflows hang off `IntegrationTests`.

Run locally with `./scripts/run-xcode-tests.sh -t AppSmokeTests`.
