# Spec: External Podcast Directory Search

**Issue**: #442
**Feature**: External podcast directory search via iTunes Search API and PodcastIndex

---

## Scenarios

### Search by podcast name

```
Given the user is on the Discover tab
When they type "Hard Fork" in the search field
Then results from iTunes Search API appear
And each result shows title, author, artwork thumbnail, and episode count
```

### Subscribe from search result

```
Given search results are displayed on the Discover tab
When the user taps "Subscribe" on a result
Then the full RSS feed is fetched and parsed
And the podcast appears in the Library with real episodes
```

### Episode count display

```
Given a directory search result has an episodeCount field
When the result is displayed in the search list
Then the episode count badge shows (e.g., "300 episodes")
And the badge uses accessibilityIdentifier "SearchResult.EpisodeCount"

Given a local search result or a result without episodeCount
When the result is displayed
Then no episode count badge is shown
```

### PodcastIndex search (opt-in)

```
Given PODCAST_INDEX_API_KEY and PODCAST_INDEX_API_SECRET are set in Info.plist
When the user searches for a podcast
Then results from both iTunes and PodcastIndex are shown
And results with the same feed URL are deduplicated (iTunes result wins)

Given PodcastIndex keys are NOT configured
When the user searches
Then only iTunes results appear
And no error is shown
```

### Graceful degradation

```
Given one search provider fails with a network error
When the user searches
Then results from the remaining providers still appear
And no error dialog is shown to the user

Given ALL search providers fail
When the user searches
Then local library search results still appear
And no error dialog is shown (directory failures are non-fatal)
```

---

## Edge Cases

- **Empty query**: Search field blank → no search fired, existing results cleared
- **Already subscribed**: Result matching a subscribed podcast → shows "Subscribed" badge, no Subscribe button
- **No results from any provider**: Shows "No results found" empty state
- **PodcastIndex keys partially configured**: If only API key or only secret is set, PodcastIndex is excluded (failable init returns nil)
- **Duplicate feed URLs across providers**: First provider's result wins; subsequent duplicates dropped

---

## Architecture Notes

- `PodcastDirectorySearching` protocol — implemented by `ITunesSearchProvider`, `PodcastIndexSearchProvider`, and `AggregateSearchProvider`
- `AggregateSearchProvider` runs all providers concurrently via `withTaskGroup`; absorbs individual provider failures
- Episode count flows via `SearchViewModel.episodeCountMap: [String: Int]` (keyed by feed URL); cleared on `clearSearch()`; never persisted
- PodcastIndex auth: `SHA1(apiKey + apiSecret + epochSeconds)` sent as `Authorization` header
