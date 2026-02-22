

## Update Log
- 2025-09-27 20:38 ET: Restored shared `zpod` scheme (app target) and refreshed `run-xcode-tests.sh` default plus simulator fallbacks to avoid confusion with the SwiftPM auto-generated scheme.
- 2026-02-21 19:33 ET: Fixed `run-xcode-tests.sh` summary/reporting gaps for UI-suite boot failures.
  - Added UI summary fallback so failed `zpodUITests/*` suites still appear in `Test Results` even when no suite-level xcresult timing rows are available.
  - Added UI timing fallback to derive per-suite timing from phase entries when xcresult parsing has no test nodes.
  - Normalized group totals in test aggregation to prevent inconsistent output where `total < passed + failed + skipped`.
  - Fixed boot failure status propagation in two call sites by capturing the real `boot_simulator_destination` exit code (instead of the `if ! ...` inverted status), so simulator boot timeouts now fail the run with non-zero exit.
  - Added UI orchestration recovery: after first suite failure (without fresh-sim mode), remaining suites automatically switch to fresh simulators and reset CoreSimulator service once.
- 2026-02-22 06:41 ET: Fixed duplicate end-of-run summaries caused by trap inheritance in lint/test pipelines.
  - Root cause: child shells spawned by pipelines inherited `EXIT`/`ERR` traps and could call `finalize_and_exit`, emitting an extra summary block before the parent process finalized.
  - Added root-shell PID guards to `handle_exit`, `handle_unexpected_error`, and `handle_interrupt` so only the original `run-xcode-tests` process can finalize/report.
  - Validation: `./scripts/run-xcode-tests.sh -l` now emits a single summary block (`TestResults/TestResults_20260222_064101_lint_swift.log` contains one `Overall Status` section).
