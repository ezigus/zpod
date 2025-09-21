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
