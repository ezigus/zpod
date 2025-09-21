# Dev Log – Issue 01.1.1 Build Script Modernization

## 2025-09-21 13:05 EDT — Planning & Issue Split
- Reviewed legacy Issue 01.1.1 scope; split into two focused work items:
  - **01.1.1.1** (#63) – Introduce shared shell helpers and refactor `run-xcode-tests.sh` with environment detection + self-checks.
  - **01.1.1.2** (#64) – Adopt the new tooling inside GitHub Actions, refresh docs, and align auxiliary scripts.
- Captured parent issue history in `Issues/01.1.1-build-script-modernization.md`; updated GitHub issue #60 accordingly.
- High-level plan for Phase 1 (Issue 01.1.1.1):
  1. Create `scripts/lib/` with `logging.sh`, `env.sh`, and `args.sh` helpers (shellcheck clean).
  2. Rewrite `run-xcode-tests.sh` to source helpers, expose `--self-check`, and centralise build/test orchestration.
  3. Provide fallback adapters (`lib/xcode.sh`, `lib/spm.sh`) so platform differences are encapsulated.
  4. Add lightweight sanity tests (bash-driven) to guard argument parsing and environment detection.
- Phase 2 (Issue 01.1.1.2) will start only after Phase 1 lands so that CI switches to the new entry point with confidence.

Next step: create a working branch for Issue 01.1.1.1 and begin implementing shared helpers + script refactor.

## 2025-09-21 13:55 EDT — Phase 1 Refactor Started
- Created `feature/01.1.1-script-refactor` branch and PR #65 (ties to Issue #63).
- Added `scripts/lib/` with common helpers:
  - `logging.sh` for structured colourised output.
  - `common.sh` for repo/root utilities.
  - `result.sh` for result bundle/log path management.
  - `xcode.sh` and `spm.sh` to encapsulate environment detection and fallback execution.
- Rewrote `scripts/run-xcode-tests.sh` to source helpers, simplify build/test orchestration, add `--self-check`, and centralise xcodebuild/SPM handling.
- Updated `scripts/dev-build-enhanced.sh` to reuse new logging utilities.
- Verified `bash -n` on all scripts and ran `run-xcode-tests.sh --self-check` plus `scripts/dev-build-enhanced.sh syntax` as smoke tests.

Next: iterate on documentation updates and add lightweight shell-based self-tests before tackling CI integration (Issue #64).

## 2025-09-21 14:05 EDT — Full Build Verification
- Added environment guard/`MACOSX_DEPLOYMENT_TARGET` when invoking SwiftPM to avoid macOS availability compilation errors during fallbacks.
- Updated simulator selection to ignore placeholder entries when real devices exist so the script mirrors manual `xcodebuild -showdestinations` behaviour.
- `scripts/run-xcode-tests.sh full_build_and_test` now runs xcodebuild clean+build and UI tests against the concrete simulator (subsequent UI test failure is unrelated test logic, not simulator detection).

## 2025-09-21 15:20 EDT — Kickoff Phase 2 CI Integration
- Created branch `feature/01.1.1.2-ci-integration` for Issue #64 (CI workflow integration).
- Goal: replace duplicated xcodebuild invocations in `.github/workflows/ci.yml` with the new `scripts/run-xcode-tests.sh` entry point, ensure Linux fallback uses SPM, and update contributor docs accordingly.
- Next steps: review existing workflow steps, stage modifications to call the script with flags, and update documentation/test summaries once verified.

## 2025-09-21 15:35 EDT — Workflow & Documentation Updates
- Refactored `.github/workflows/ci.yml` to rely on `./scripts/run-xcode-tests.sh` (`--self-check` + `full_build_and_test`) and added a Linux job that exercises the SwiftPM fallback via `dev-build-enhanced.sh`.
- Tidied macOS steps (removed manual package resolution/xcbeautify install) while keeping simulator installation safeguards.
- Updated `AGENTS.md` to direct developers toward the helper script for local/CI usage.
- Verified via `scripts/run-xcode-tests.sh --self-check` and `scripts/dev-build-enhanced.sh syntax` locally. Full suite run pending CI.

## 2025-09-21 15:45 EDT — CI Trigger Cleanup
- Restricted the workflow triggers so pushes only run CI on `main`; feature branches now rely on the PR event. This prevents duplicate runs on every push + PR update.
