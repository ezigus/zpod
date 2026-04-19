# Podcast Addict — Feature Research

Competitive analysis of [Podcast Addict](https://play.google.com/store/apps/details?id=com.bambuna.podcastaddict) (Android), focusing on priority, sorting, and automated playlist capabilities.

**Research date:** 2026-04-18

---

## 1. Priority System (-10 to +10)

### Configuration

- **Location:** Long-press a podcast > **Custom Settings** > **Podcast Priority**
- **Range:** Integer values from **-10** (lowest) to **+10** (highest)
- **Default:** `0` for newly subscribed podcasts

### What Priority Affects

| Area | Behavior |
|------|----------|
| **Playlist sorting** | When the playlist is sorted by priority, episodes from higher-priority podcasts are played first. |
| **Episode ordering within priority** | Within the same priority level, the **oldest unplayed episodes play first** (FIFO within band). |
| **Download queue** | Higher-priority podcasts' episodes are downloaded before lower-priority ones. |
| **Podcast list** | The main podcast list can be sorted by priority. |
| **Automatic playlist** | When auto-playlist adds newly downloaded episodes, higher-priority episodes are queued higher. |

### Key Behaviors

- Priority acts as the **primary sort key**; a secondary sort (usually publication date) breaks ties within the same priority band.
- Works in conjunction with the **"Alternate by podcast"** playlist mode — priority determines the round-robin order between podcasts.
- The official Podcast Addict Twitter account confirmed: *"You will be able to sort your playlist by priority so your favorite podcasts are always played first."*

---

## 2. Sorting Capabilities

Podcast Addict offers sorting at multiple levels throughout the app, with the option for per-screen custom sorting modes.

### 2.1 Episode Sorting (within a podcast)

| Sort Option | Direction |
|-------------|-----------|
| Publication date | Newest → Oldest / Oldest → Newest |
| Download date | Newest → Oldest / Oldest → Newest |
| Duration | Shortest → Longest / Longest → Shortest |
| Remaining time | Ascending / Descending |
| File size | Smallest → Largest / Largest → Smallest |
| Episode name | A → Z / Z → A |
| Rating | High → Low / Low → High |
| Custom | Manual drag & drop reorder |

- **Per-podcast custom sorting:** Enable via **Settings > Display > Podcasts > Custom Sorting**. Each podcast screen can have its own unique sorting mode.
- **Natural sorting:** Properly handles numbered episode titles (e.g., `episode_1, episode_2, episode_10` sort numerically, not lexicographically).

### 2.2 Podcast List Sorting (main screen)

| Sort Option | Notes |
|-------------|-------|
| Name / Title | Alphabetical |
| Priority | By the -10 to +10 priority value |
| Unread count | Podcasts with more unread episodes first |
| Last updated | Most recently updated first |
| Date added | By subscription date |
| Custom | Manual drag & drop via **"Reorder (Drag & Drop)"** option menu |

To reorder manually: select the **"Custom"** sorting mode, then press **"Reorder"** in the options menu. Drag handles appear on each podcast.

### 2.3 Playlist Sorting

| Sort Option | Notes |
|-------------|-------|
| Publication date | New → Old / Old → New |
| Download date | New → Old / Old → New |
| Duration | Short → Long / Long → Short |
| Episode name | Alphabetical |
| File name | Alphabetical |
| Priority | Sorts by podcast priority value (-10 to +10) |
| Custom / Manual | Drag & drop reorder |

#### Special Playlist Sort Modes

- **Alternate by podcast** (added in v3.43): Instead of strict sort order, the playlist round-robins between podcasts. For example, with "Publication date New→Old + Alternate", it plays the newest episode from Podcast A, then the newest from Podcast B, then C, etc., instead of playing all recent episodes from the same podcast consecutively.
- **Natural sorting** (togglable in **Settings > Playlist > Natural Sorting**): Handles numbered episode names properly in the playlist view.

### 2.4 Playback Order Controls

These complement sorting within the playlist:

| Control | Behavior |
|---------|----------|
| **Play from Top** | After current episode finishes, always returns to the first episode in the list. Useful with priority sorting to ensure highest-priority episodes are always played first. |
| **Shuffle mode** | Randomizes playback order within the playlist. |
| **Loop / Repeat** | Loops the playlist after all episodes are played. |

---

## 3. Automated Playlist System

This is Podcast Addict's most feature-rich area. The app provides a sophisticated multi-layered system combining automatic episode management, category-based virtual playlists, per-podcast filtering, and intelligent playback controls.

### 3.1 Two Main Playback Modes

#### Playlist Mode (default: **enabled**)
- **Setting:** Settings > Playlist > Enable Playlist
- "Add to playlist" buttons appear on all episodes
- Pressing an episode's PLAY button adds it to the playlist and starts playback
- Queue is viewable by opening the player screen and **swiping left**
- Supports manual reordering via drag & drop
- Shows **total playlist duration** via options menu on the player screen's playlist tab

#### Continuous Playback Mode (default: **disabled**)
- **Setting:** Settings > Playlist > Continuous Playback
- Press play on any episode and the app **automatically creates a temporary queue** with all unplayed episodes displayed on the current screen
- Respects active screen filters — e.g., if you open the "Favorites" screen and press play, only favorite episodes are queued
- No manual queue management needed; the app handles it dynamically

### 3.2 Category-Based Custom Playlists (v3.42+)

Podcast Addict's approach to "multiple playlists" uses a category/filter system:

- **Access:** Playlists screen > **Custom** tab
- **Categories** can come from:
  - RSS feed categories provided by podcast publishers
  - **User-created categories** (via the toolbar "Category" button)
- Users can create themed playlists like "News", "Commute", "Work", etc.
- **Each category has its own independent filter** with these criteria:

| Filter Criterion | Options |
|------------------|---------|
| Episode status | Played / Unplayed |
| Download status | Downloaded / Not downloaded |
| Favorite status | Favorites only |
| Publication date | Date range filtering |

- Select a category from the **upper dropdown menu** to listen to only that category's episodes
- **Auto-transition:** When all unplayed episodes in a category are finished, the app can **automatically switch** to another category or a live radio station

### 3.3 Automatic Playlist Management

#### Automatic Playlist (auto-add)
- **Setting:** Settings > Playlist > Automatic Playlist
- Newly downloaded episodes are **automatically added** to the playlist
- Works with the auto-download feature: new episode publishes → auto-downloads → auto-added to playlist
- Respects podcast priority: higher-priority podcast episodes are queued above lower-priority ones

#### Automatic Dequeue (auto-remove)
- **Setting:** Settings > Playlist > Automatic Dequeue
- Episodes are **automatically removed** from the playlist once fully listened to
- Reduces manual playlist maintenance

### 3.4 Episode Filtering (per-podcast)

- **Access:** Long-press podcast > Custom Settings > Episode Filter
- Keyword-based include/exclude rules:
  - **Comma-separated keywords** = logical AND (all must match)
  - **New lines** = logical OR (any can match)
- Filter by:
  - Episode type
  - Episode title
  - Episode duration
- **Important behavior:** Filters only apply to **newly retrieved content**. To apply retroactively to existing episodes, long-press the podcast and select **"Reset"**.

### 3.5 Automatic Cleanup & Retention

- **Setting:** Settings > Automatic Cleanup

| Cleanup Option | Description |
|----------------|-------------|
| Delete after playback | Auto-delete downloaded file after episode is fully played |
| Delete by age | Auto-delete based on episode publication date |
| Delete when marked played | Auto-delete when manually marked as played (default: **off**) |
| Episode retention limit | "Number of downloaded episodes to keep" per podcast |

- All cleanup settings can be **overridden per-podcast** via Custom Settings
- Cleanup only affects **downloaded files**, not the episode entries themselves

### 3.6 Per-Podcast Custom Settings

All of the following can be customized independently for each podcast (long-press > Custom Settings):

| Setting Category | Customizable Options |
|------------------|---------------------|
| **Priority** | -10 to +10 |
| **Auto download** | Enable/disable per podcast |
| **Auto deletion** | Override global cleanup rules |
| **Episode filter** | Include/exclude keyword rules |
| **Sorting mode** | Custom sort order per podcast |
| **Player settings** | Playback speed, volume boost, skip silence |
| **Playlist settings** | Playlist behavior overrides |
| **Notifications** | Per-podcast notification preferences |

### 3.7 Queue Management Features

| Feature | Description |
|---------|-------------|
| **Manual reorder** | Drag & drop episodes in the queue (swipe left on player screen) |
| **Total duration** | View total remaining playlist time via options menu |
| **Shuffle** | Randomize playback order |
| **Play from Top** | Always restart from first episode after current finishes |
| **Alternate by podcast** | Round-robin between podcasts instead of sequential play |

### 3.8 Additional Features

| Feature | Description |
|---------|-------------|
| **Virtual podcasts** | Treat a local folder's contents as a podcast, manageable in playlists |
| **Audio & video in same playlist** | Mixed media type support |
| **Bookmarks** | Save specific moments within episodes |
| **Sleep timer** | Auto-stop playback after a set time |
| **Variable playback speed** | Per-podcast or global speed adjustment |
| **Volume boost** | Amplify quiet audio |
| **Skip silence** | Automatically skip silent segments |
| **Chapter support** | Navigate by chapter markers |
| **OPML import/export** | Transfer subscriptions between apps |
| **Playback statistics** | Track listening history and stats |
| **Chromecast / Sonos** | Cast playback to external devices |
| **Android Auto** | In-car playback integration |
| **Wear OS** | Smartwatch control support |

---

## Sources

- [Podcast Addict FAQ: Playlist / Continuous Playback](https://podcastaddict.com/faq/210)
- [Podcast Addict FAQ: Custom Settings Per Podcast](https://podcastaddict.com/faq/340)
- [Podcast Addict FAQ: Custom Sorting Modes](https://podcastaddict.com/faq/530)
- [Podcast Addict FAQ: Organizing Podcasts](https://podcastaddict.com/faq/330)
- [Podcast Addict FAQ: Episode Filtering](https://podcastaddict.com/faq/370)
- [Podcast Addict FAQ: Playlist Order](https://podcastaddict.com/faq/400)
- [Podcast Addict FAQ: Removing Old Episodes](https://podcastaddict.com/faq/420)
- [Podcast Addict FAQ: Automatic Cleanup](https://podcastaddict.com/faq/290)
- [Podcast Addict FAQ: Automatic Downloads](https://podcastaddict.com/faq/280)
- [Podcast Addict Getting Started Guide](https://podcastaddict.com/getting_started)
- [Podcast Addict v3.42 Release (Custom Tabs)](https://www.facebook.com/podcastAddict/photos/1301889306546578/)
- [Podcast Addict v3.43 Release (Alternate Sort)](https://www.facebook.com/podcastAddict/photos/1314495925285916/)
- [Podcast Addict on X: Priority Sorting](https://x.com/podcastaddict/status/823954695274143745)
- [Podcast Addict on Google Play](https://play.google.com/store/apps/details?id=com.bambuna.podcastaddict)
- [Podcast Addict on AlternativeTo](https://alternativeto.net/software/podcast-addict/about/)
- [CoolBlindTech: Podcast Addict Introduction](https://coolblindtech.com/podcast-addict-for-android-a-quick-introduction/)

---

## 4. Gap Analysis: zpod vs Podcast Addict

Comparison of zpod's current specs and implementation against Podcast Addict's feature set. Each gap describes what zpod would need to add or change to achieve parity.

### 4.1 Priority System

| Aspect | Podcast Addict | zpod Current State | Gap |
|--------|---------------|-------------------|-----|
| **Per-podcast priority** | Integer -10 to +10, set per podcast | No per-podcast priority concept exists | **NEW FEATURE** needed: `priority: Int` on Podcast model (-10...+10, default 0) |
| **Download priority** | Priority affects download queue order | `DownloadPriority` enum with 3 levels: `.low`, `.normal`, `.high` (`DownloadTask.swift`) | **ENHANCE**: Bridge podcast priority → download priority. Current 3-level enum is too coarse; either map ranges (-10...-4 = low, -3...3 = normal, 4...10 = high) or replace with the integer system |
| **Playlist sort by priority** | Sorts playlist episodes by their podcast's priority value | `EpisodeSortBy` has no `.priority` case (`EpisodeFiltering.swift:6-14`) | **ADD**: New `.priority` case to `EpisodeSortBy` enum and corresponding sort logic in `EpisodeSortService` |
| **Intra-priority ordering** | Within same priority band, oldest episodes first (FIFO) | N/A | **ADD**: Secondary sort logic — when primary sort is priority, break ties by publication date ascending |
| **Priority in auto-playlist** | Higher priority podcasts' new downloads queued higher | No automatic playlist feature exists | Depends on auto-playlist feature (see 4.3) |

**Spec changes needed:**
- New spec for per-podcast priority setting UI and storage
- Update `EpisodeSortBy` enum to include `.priority` case
- Update download queue to respect podcast-level priority

### 4.2 Sorting Capabilities

#### Episode Sorting (`EpisodeSortService.swift`, `EpisodeFiltering.swift`)

| Sort Option | Podcast Addict | zpod | Gap |
|-------------|---------------|------|-----|
| Publication date (newest/oldest) | Yes | Yes (`.pubDateNewest`, `.pubDateOldest`) | -- |
| Download date | Yes | No | **ADD** `.downloadDate` case |
| Duration | Yes (both directions) | Yes (shortest only, `.duration`) | **ADD** `.durationLongest` for reverse direction |
| Remaining time | Yes | No | **ADD** `.remainingTime` case (requires `duration - playbackPosition`) |
| File size | Yes | No | **ADD** `.fileSize` case (requires file size on Episode model) |
| Episode name | Yes (A-Z / Z-A) | Yes (A-Z only, `.title`) | **ADD** `.titleDescending` for reverse direction |
| Rating | Yes (both directions) | Yes (high→low only, `.rating`) | **ADD** `.ratingAscending` for reverse direction |
| Date added | Yes | Yes (`.dateAdded`) | -- |
| Play status | Yes | Yes (`.playStatus`) | -- |
| Download status | Yes | Yes (`.downloadStatus`) | -- |
| Custom (drag & drop) | Yes | No | **ADD** manual reorder support |
| Natural sorting | Yes (ep1, ep2, ep10) | No | **ADD** numeric-aware string comparison |
| Per-podcast custom sort | Yes (each podcast can have own sort mode) | No | **ADD** per-podcast sort preference storage |

#### Podcast List Sorting

| Sort Option | Podcast Addict | zpod | Gap |
|-------------|---------------|------|-----|
| Name | Yes | Unknown (no podcast list sort spec found) | **ADD** podcast list sorting feature |
| Priority | Yes | No priority system | Depends on 4.1 |
| Unread count | Yes | No | **ADD** |
| Last updated | Yes | No | **ADD** |
| Date added/subscribed | Yes | No | **ADD** |
| Custom (drag & drop) | Yes | No | **ADD** |

**Spec changes needed:**
- New spec for podcast list sorting (6 sort modes)
- Extend `EpisodeSortBy` with missing cases (download date, remaining time, file size, reverse directions)
- Per-podcast sort override setting

#### Playlist Sorting

| Sort Option | Podcast Addict | zpod | Gap |
|-------------|---------------|------|-----|
| Publication date | Yes | Yes (via `EpisodeSortBy`) | -- |
| Download date | Yes | No | Same gap as episode sorting |
| Duration | Yes | Yes | -- |
| Episode name | Yes | Yes (via `PlaylistSortCriteria.titleAscending/Descending`) | -- |
| File name | Yes | No | Minor — episode name is likely equivalent |
| Priority | Yes | No | Depends on 4.1 |
| Custom/Manual | Yes | Yes (drag & drop in `InMemoryPlaylistManager.reorderEpisodes`) | -- |
| **Alternate by podcast** | Yes (round-robin between podcasts) | No | **ADD**: New playlist sort mode that interleaves episodes from different podcasts |
| Natural sorting | Yes (toggle) | No | **ADD** |

#### Playback Order Controls

| Control | Podcast Addict | zpod | Gap |
|---------|---------------|------|-----|
| Play from Top | Yes | No | **ADD**: After current episode finishes, restart from first in list |
| Shuffle | Yes | Yes (`shuffleAllowed` on `Playlist`) | -- |
| Loop/Repeat | Yes | No | **ADD** |

### 4.3 Automated Playlist System

#### Playback Modes

| Feature | Podcast Addict | zpod | Gap |
|---------|---------------|------|-----|
| Manual Playlist | Yes (add-to-playlist buttons) | Yes (`Playlist` model with `episodeIds`) | -- |
| Continuous Playback | Yes (auto-queue unread episodes from same podcast on play) | No | **NEW FEATURE**: When pressing play on an episode, auto-create temporary queue of unread episodes from same podcast displayed on screen |
| Continuous Playback respects screen filters | Yes | N/A | Part of continuous playback feature |

#### Category-Based Virtual Playlists

| Feature | Podcast Addict | zpod | Gap |
|---------|---------------|------|-----|
| Category tabs | Yes (Custom tab with category dropdown) | No — zpod uses rule-based smart playlists instead | **DESIGN DECISION**: zpod's SmartEpisodeListV2 is more powerful than PA's category system. Consider whether to add simple category shortcuts as "quick filters" on top of the existing rules engine, or stay with the rules-only approach |
| User-created categories | Yes | Partially — smart playlist templates serve a similar role | Templates exist but aren't category-based |
| Per-category filters (played/downloaded/favorites/date) | Yes | SmartEpisodeListV2 rules cover all these criteria and more | zpod is **ahead** here — 13 rule types with AND/OR/NOT vs PA's 4 simple filters |
| Auto-transition between categories | Yes (switch to another category or radio when done) | No | **ADD**: "When playlist finishes, play from..." setting |

#### Automatic Episode Management

| Feature | Podcast Addict | zpod | Gap |
|---------|---------------|------|-----|
| **Automatic Playlist** (auto-add downloaded episodes) | Yes (`Settings > Playlist > Automatic Playlist`) | No | **NEW FEATURE**: Setting to auto-add newly downloaded episodes to a designated playlist |
| **Automatic Dequeue** (auto-remove after playing) | Yes (`Settings > Playlist > Automatic Dequeue`) | No | **NEW FEATURE**: Setting to auto-remove episodes from playlist after fully played |
| **Automatic Cleanup** (delete files after play) | Yes (multiple options) | No automatic cleanup spec found | **NEW FEATURE**: Auto-delete downloaded files after playback, by age, or by retention limit |
| **Episode retention limit** (keep N downloaded per podcast) | Yes (per-podcast override) | No | **ADD** to per-podcast settings |

#### Episode Filtering (per-podcast)

| Feature | Podcast Addict | zpod | Gap |
|---------|---------------|------|-----|
| Keyword include/exclude | Yes (AND via comma, OR via newline) | zpod's `SmartListRuleType.title` and `.description` with `.contains`/`.notContains` | zpod's rule system is more structured; PA's keyword approach is simpler for users |
| Filter by episode type | Yes | No explicit episode type filter | **ADD** if zpod has an episode type field |
| Filter by duration | Yes | Yes (via smart list rules) | -- |
| Retroactive filter reset | Yes (long-press > Reset to reapply) | No equivalent | **ADD** if implementing per-podcast keyword filters |

#### Queue Management

| Feature | Podcast Addict | zpod | Gap |
|---------|---------------|------|-----|
| Manual reorder (drag & drop) | Yes | Yes (`reorderEpisodes` in playlist manager) | -- |
| Total playlist duration | Yes (options menu) | No | **ADD**: Compute and display sum of episode durations in playlist |
| Queue view (swipe left on player) | Yes | No spec for queue access gesture | **ADD** to player UI spec |

#### Per-Podcast Custom Settings

| Feature | Podcast Addict | zpod | Gap |
|---------|---------------|------|-----|
| Priority override | Yes (-10 to +10) | No | See 4.1 |
| Auto-download per podcast | Yes | Unclear — `AutoDownloadService.swift` exists but per-podcast override not confirmed | **VERIFY** and add if missing |
| Auto-deletion per podcast | Yes | No | **ADD** |
| Episode filter per podcast | Yes | No per-podcast filter spec | **ADD** |
| Sort mode per podcast | Yes | No | **ADD** |
| Player settings per podcast | Yes (speed, volume, skip silence) | No spec for per-podcast playback settings | **ADD** |
| Playlist settings per podcast | Yes | No | **ADD** |
| Notification settings per podcast | Yes | No | **ADD** |

#### Additional Features

| Feature | Podcast Addict | zpod | Gap |
|---------|---------------|------|-----|
| Virtual podcasts (local folder as podcast) | Yes | No | **NEW FEATURE** (lower priority) |
| Mixed audio & video playlist | Yes | No video support | N/A — zpod is audio-focused |
| Bookmarks | Yes | Yes (`.isBookmarked` rule type exists) | -- |
| Sleep timer | Yes | Exists (referenced in playback settings) | -- |
| Variable playback speed | Yes | Yes | -- |
| Skip silence | Yes | Unclear | **VERIFY** |
| Chapter support | Yes | Unclear | **VERIFY** |
| OPML import/export | Yes | Import exists (`spec/settings.md`), export exists | -- |
| Playback statistics | Yes | Unclear | **VERIFY** |

---

## 5. Recommended Spec Changes (Priority Order)

### P0 — High Impact, Core Differentiators

1. **Per-Podcast Priority System** (`NEW SPEC`)
   - Add `priority: Int` (-10...+10) to Podcast model
   - Add UI for setting priority (long-press or podcast settings)
   - Add `.priority` case to `EpisodeSortBy`
   - Wire priority into download queue ordering
   - Files to modify: `EpisodeFiltering.swift`, `EpisodeSortService.swift`, `DownloadTask.swift`, Podcast model

2. **Automatic Playlist Management** (`NEW SPEC`)
   - Auto-add newly downloaded episodes to playlist
   - Auto-remove episodes from playlist after fully played
   - Settings toggles for both behaviors
   - Priority-aware insertion order

3. **Alternate-by-Podcast Sort Mode** (`UPDATE spec/06.1.2`)
   - Round-robin interleaving of episodes from different podcasts in playlist
   - Prevents one prolific podcast from dominating the queue

### P1 — Important Enhancements

4. **Extended Sort Options** (`UPDATE EpisodeSortBy`)
   - Add: download date, remaining time, file size, reverse directions for duration/title/rating
   - Add: natural sorting for numbered episode titles

5. **Podcast List Sorting** (`NEW SPEC`)
   - Sort the main podcast list by: name, priority, unread count, last updated, date added, custom

6. **Continuous Playback Mode** (`NEW SPEC`)
   - Press play on episode → auto-queue all unread episodes from same podcast
   - Respects active screen filters
   - Toggle in Settings > Playlist

7. **Automatic Cleanup & Retention** (`NEW SPEC`)
   - Delete downloaded files after playback
   - Delete by age (publication date threshold)
   - Episode retention limit per podcast (keep N downloaded)

### P2 — Nice-to-Have Enhancements

8. **Per-Podcast Custom Settings System** (`NEW SPEC`)
   - Override auto-download, auto-delete, sort mode, playback speed, episode filter per podcast
   - Long-press > Custom Settings UI

9. **Playback Order Controls** (`UPDATE player spec`)
   - Play from Top (always restart from first episode)
   - Loop/Repeat mode

10. **Auto-Transition** (`NEW SPEC`)
    - When playlist/category finishes, auto-switch to another playlist or stop

11. **Total Playlist Duration Display** (`UPDATE playlist UI spec`)
    - Sum and display total remaining time in playlist view

### Where zpod Is Already Ahead

- **Smart playlist rules engine**: zpod's 13 rule types with AND/OR/NOT logic and negation is significantly more powerful than Podcast Addict's simple 4-criterion category filters
- **Rule templates**: zpod has built-in templates for common scenarios
- **Live preview**: zpod spec includes live preview of matching episodes during rule creation
- **Duplicating playlists**: zpod supports duplicating smart playlists with independent editing
