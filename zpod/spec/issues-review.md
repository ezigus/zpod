# Issues Summary & Ordering Review

Generated: 2025-08-10
Source of truth: GitHub issues #1–#33 (open at generation time)

## 1. Scope
This document provides:
- Concise summary of each implementation issue (spec-derived) with status, wave, dependency notes, risk level.
- Traceability back to specification sections.
- Recommended execution ordering (waves) & critical path.
- Parallelization lanes and early quality gates (accessibility, privacy, sync) timing.
- Adjustment recommendations (reorders / merges / defers).

## 2. Legend
- Wave: Suggested milestone grouping (earlier waves are higher priority / foundational).
- Risk: H = architectural/complex uncertainty, M = moderate complexity, L = straightforward.
- CP: On critical path (must complete before significant downstream value).
- Deferred: Intentionally late to avoid rework.

## 3. Recommended Waves Overview
| Wave | Theme | Primary Goals |
|------|-------|---------------|
| 0 | Bootstrap | (Issue #1 test only – not part of spec work) |
| 1 | Core Ingestion & Basic Playback | 01,02,03 |
| 2 | Platform Foundations (Settings, Downloads, Org) | 04,05,06,07,10,11 |
| 3 | Playback Expansion & Library Enrichment | 08,09*,12,13,14,15,16,17,18 (see note) |
| 4 | Advanced UX & Media Surfaces | 19,20,21,22,23,24,25 |
| 5 | Satellite Platforms & Surfaces | 26 (phase 1 accessibility actually should straddle), 27,28,29 |
| 6 | External Content & Data Management | 30,31,32,33 |
| 7 | Future / Follow-ups (not yet issued) | Auto transcript gen, ML recs, Live Activities, etc. |

*Note: Issue numbering mismatch: GitHub #9 titled "08-Advanced Search" etc. Table uses internal feature IDs.

Accessibility (26) should begin as soon as first UI surfaces (after Wave 2) — treat as **ongoing gate** not end-of-line feature; therefore split: 26a (baseline) in Wave 3, 26b (advanced) future.

## 4. Critical Path (High-Level)
01 Subscription → 02 Episode Detail (stub) → 03 Playback Engine → 05 Settings Framework → 04 Download Core (feeds from subscription & playback consumption) → 06 Per-Podcast/Global Settings Integration (actually part of 05) → 10 Update Frequency → 11 OPML → 15 Cloud Sync (needs stable data schemas) → 16/17/18 Playback Enhancements → 19 Transcript → 20 Video → 21 Casting → 22/23 Sharing → 24 Notifications → 25 Parental Controls → 32 Privacy/App Lock → 31 Backup/Restore.

## 5. Issue Traceability & Ordering Detail
| GH # | Internal ID / Title | Wave | CP | Risk | Depends On | Enables | Key Spec Sections |
|------|---------------------|------|----|------|-----------|---------|-------------------|
| 2 | 01-Subscribe | 1 | Y | M | — | 02,04,05,07,10,11,15,12 | discovery.md subscribe |
| 3 | 02-Episode Detail + Stub Playback | 1 | Y | L | 01 | 03, basic UX tests | playback.md (basic) |
| 4 | 03-Playback Engine (AVFoundation) | 1 | Y | H | 02 | 16–18,19,20,21,17, speed/skip features | playback.md core |
| 5 | 04-Download Core | 2 | Y | H | 01 (episodes), 03 (later integration) | Auto-download triggers, storage policies, notifications (24) | download.md |
| 6 | 05-Settings Framework | 2 | Y | M | 01 (podcasts reference) | Playback intervals, per-podcast overrides (03,16,18) | settings.md, customization.md |
| 7 | 07-Folder/Tag Organization | 2 | N | M | 01 | Advanced filtering, recommendations context | customization.md, discovery.md |
| 8 | 06-Playlist & Smart Playlist | 2 | N | H | 01,03,04 | Shuffle, queue mgmt, rec surfaces | customization.md, playback.md |
| 9 | 08-Advanced Search | 3 | N | H | 01, (episodes metadata via 03/04) | Unified search, parental filters (25) | discovery.md, playback.md |
| 10 | 10-Per-Podcast Update Frequency | 2 | N | M | 01,05 | Timely auto download, stats recency | discovery.md, settings.md |
| 11 | 11-OPML Import/Export | 2 | N | M | 01 | Backup (31) baseline, migration | discovery.md, settings.md |
| 12 | 12-Recommendations Baseline | 3 | N | M | 01,13 (later) | Widgets (29), CarPlay rec future | discovery.md, ui.md |
| 13 | 13-Listening History & Stats | 3 | Y | H | 03 | 12 (data), 14 notes context, 31 export | advanced.md, settings.md |
| 14 | 14-Bookmarks & Episode Notes | 3 | N | M | 03,13? optional | Transcript linking, clip share (23) | advanced.md, playback.md |
| 15 | 15-Cloud Sync Core | 3 | Y | H | 01,05, (04 optional) | Cross-device continuity, later transcript/notes sync | settings.md, advanced.md |
| 16 | 16-Playback Effects | 3 | N | H | 03,05 | Enhanced playback quality, casting parity | playback.md |
| 17 | 17-Sleep/Alarm Enhancements | 3 | N | M | 03,05 | Notifications (24), watch features (27) | playback.md |
| 18 | 18-Intro/Outro & Chapters UI | 3 | N | M | 03,05 | Video timeline, transcripts alignment (19) | playback.md |
| 19 | 19-Transcript View | 4 | N | M | 03 (time), 15 (future sync) | Accessibility audit (26), search (08) integration | playback.md |
| 20 | 20-Video & PiP | 4 | N | H | 03,18 | Casting (21), Widgets (29) richness | playback.md video |
| 21 | 21-Casting Abstraction | 4 | N | H | 03,20 | Multi-device playback experiences | advanced.md, ui.md |
| 22 | 22-Sharing Links | 4 | N | L | 01,05 | Clip sharing (23), marketing growth | advanced.md |
| 23 | 23-Audio Clip Sharing | 4 | N | M | 03,22 | Social growth, bookmark synergy | advanced.md |
| 24 | 24-Notifications System | 4 | Y | H | 04,17 | Engagement loops, parental filter gating | settings.md, playback.md |
| 25 | 25-Parental Controls | 4 | Y | M | 01,10 | Privacy/App Lock (32), search filtering (08) | settings.md, advanced.md |
| 26 | 26-Accessibility Audit P1 | 3 (start) | Y (quality gate) | M | 02,03 (UI surfaces), 19 (include) | All subsequent UI surfaces | ui.md accessibility |
| 27 | 27-watchOS Companion P1 | 5 | N | H | 03,16 | Extended ecosystem, complications | playback.md, advanced.md |
| 28 | 28-CarPlay Layout | 5 | N | H | 03,04 | Driving UX, recommendations extension | ui.md, settings.md |
| 29 | 29-Widgets & Shortcuts | 5 | N | M | 03,12 | Engagement entry points, deep links (22) | ui.md, customization.md |
| 30 | 30-External Content Sources | 6 | N | H | 01,05 | Broader library, rec inputs (12) | content.md |
| 31 | 31-Backup/Restore & Export | 6 | Y | H | 01,05,11,13 | Disaster recovery, migrations | settings.md, advanced.md |
| 32 | 32-Privacy/Security/App Lock | 6 | Y | M | 25 | Compliance posture, user trust | settings.md |
| 33 | 33-Help/Feedback/Diagnostics | 6 | N | L | 24 (optional), 03 logs | Support loop | advanced.md, ui.md |
| 1 | (Test issue) | 0 | N | L | — | None | — |

## 6. Parallelization Lanes
- Lane A (Playback Core): 02 → 03 → 16/17/18 → 19 → 20 → 21.
- Lane B (Data & Library): 01 → 05 → 04 → 10 → 11 → 15 → 31.
- Lane C (Discovery & Intelligence): 13 → 12 → 08.
- Lane D (User Safety & Compliance): 25 → 32.
- Lane E (Surfaces & Engagement): 22 → 23 → 24 → 29 → 27 → 28 → 33.
- Lane F (Content Expansion): 30 (after stable library models). 

Coordination Points:
- 13 must produce sufficient data before 12 yields value.
- 05 must stabilize before 15 to minimize sync schema churn.
- 22 deep link format should be finalized before 29 (widgets) to avoid updates.

## 7. Early Quality Gates & Cross-Cutting Concerns
| Concern | Earliest Start | Rationale | Recommendation |
|---------|----------------|-----------|----------------|
| Accessibility (26) | After 02/03 UI baseline | Avoid retrofitting late | Integrate linting & VoiceOver passes each wave |
| Privacy (32) | After parental controls design (25) | Shared secure storage primitives | Build shared PIN/biometric abstraction early |
| Sync (15) | After 05 stable schema | Prevent migration churn | Define versioned sync documents |
| Telemetry/Diagnostics (33 subset) | After 03 | Observability for early features | Lightweight event logger now, UI later |

## 8. Adjustments & Recommendations
1. MOVE Accessibility baseline (26) tasks into Wave 3 start; treat as recurring gating checklist (labels: a11y-required) rather than single terminal feature.
2. START minimal telemetry/log aggregator earlier (split from 33) to aid debugging for 03–05 development.
3. FINALIZE deep link schema (subset of 22) immediately after 01/02 so that 08, 29, 23 reuse consistent routing (create mini issue or annotate 22 to begin schema earlier).
4. CONSIDER splitting 15 into: 15a Auth + Key-Value Sync (subscriptions/settings) and 15b Extended Domains (playback progress, bookmarks) to reduce coupling.
5. ELEVATE 31 (Backup/Restore) before large external content (30) if data loss risk mitigation is priority; optionally swap 30 and 31 in schedule.
6. TAG high-risk H issues with design spikes (short design tickets) prior to implementation (03,04,16,20,21,30,31) to satisfy dev-log design-first rule; limit each spike to ≤1 day.
7. DEFINE common persistence abstraction early (used by 04 downloads, 05 settings, 13 history, 14 bookmarks, 30 external content) to avoid divergent storage layers.
8. ADOPT test harness for time-based playback features early (virtual clock) to stabilize 03,16,17,18 tests.

## 9. Risk Register (Top 6)
| Risk | Area | Impact | Mitigation |
|------|------|--------|------------|
| AVFoundation complexity & edge buffering | 03 | Playback reliability | Prototype minimal player + contract tests first |
| Download queue storage & race conditions | 04 | Data corruption | Use serial actor / structured concurrency pattern |
| Settings cascade ambiguity | 05 | Inconsistent behavior | Explicit resolution precedence table & unit tests |
| Sync conflict logic expansion | 15 | Data divergence | Versioned records + deterministic merge tests |
| Casting state machine complexity | 21 | User confusion | Formal state diagram + unit tests for transitions |
| External source parsing variability | 30 | Crashes / invalid data | Strict validation + fallback models |

## 10. Traceability Matrix (Spec Section → Issues)
| Spec Section | Issue(s) |
|--------------|----------|
| discovery.md (Subscribe) | 01,10,11,12 |
| playback.md core | 02,03,16,17,18,19,20 |
| playback.md advanced (effects, chapters, transcripts, PiP, sleep) | 16–20 |
| download.md | 04,05 (wifi/retention parts), 10 (frequency), 31 (backup) |
| settings.md | 05,10,15,24,25,32,31 |
| customization.md | 05,06,07,08 playlists, tags, per-podcast overrides |
| advanced.md | 12,13,14,15,16,21,22,23,24,25,31,33 |
| content.md | 30 |
| ui.md | 02,03,19,20,21,26,27,28,29,33 |

## 11. Deferred / Future (Not Yet Issued)
| Future Feature | Rationale for Deferral |
|----------------|------------------------|
| Live Activities / Lock Screen controls | Wait for stable playback events API |
| Auto Transcript Generation | Requires external service / ML; complexity high |
| Adaptive Silence Skip (ML/energy-based) | Build after baseline silence skip metrics collected |
| Advanced Recommendations (ML) | Need large history dataset |
| YouTube Channel Ingestion | Legal & technical considerations; after external sources foundation (30) |
| Live Radio Streaming | Similar ingestion pipeline; schedule post external sources |
| Cloud Sync of Playback Progress & Notes | Phase 2 of sync once base stable |
| Encryption of Backups | After baseline backup adoption |
| Accessibility Phase 2 (Rotor actions, custom actions) | Depends on transcript & chapters stabilization |
| Lock Screen / Watch Live Activity synergy | Subsequent to baseline watch + widgets |

## 12. Immediate Next Steps (If Adopting This Plan)
1. Create design spike tickets for 03,04,05,15 (sync split), 16 (DSP architecture) – update dev-log with diagrams.
2. Implement Wave 1 (01–03) with accessibility scoping notes added early.
3. Stand up shared persistence & test harness utilities before starting 04 & 05 concurrently.
4. Draft deep link contract (subset of 22) and place under `/spec/deeplinks.md`.
5. Add a11y checklist template to dev-log for recurring gating.

## 13. Quality Gate Checklist Template (Proposed)
```
[ ] Design entry in dev-log updated
[ ] Unit tests cover core logic + 1 edge
[ ] Accessibility labels for new UI
[ ] No force unwraps added
[ ] Persistence migrations (if any) documented
[ ] Sync schema version bumped (if applicable)
[ ] Telemetry/log events added (if applicable)
```

## 14. Summary
The ordering emphasizes stabilizing ingestion, playback, and settings before layering enhancements (effects, transcripts, video, casting), then expanding surfaces (watch, CarPlay, widgets), followed by external sources and data governance (backup, privacy). Early integration of accessibility, deep link schema, and sync domain boundaries reduces rework risk. Adjustments listed above should be applied prior to beginning Wave 2.

---
(End of document)
