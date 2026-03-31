# SearchDomain Package — Test Summary

Tests for the `SearchDomain` package, covering the local search infrastructure and
the external podcast directory search providers introduced in [#442].

## Test Files

### FoundationalSearchDomainTests.swift

**Purpose**: Core local search infrastructure — indexing, tokenization, filtering.

**Test Areas**:
- `SearchIndex` build and lookup
- `Tokenizer` normalization and stemming
- `SearchService` query execution and result ranking
- `OrganizationManagers` sort/filter helpers

### ITunesSearchProviderTests.swift

**Purpose**: Validate `ITunesSearchProvider` against a mock `URLSession` (no network).

**Specifications Covered**: `spec/442-external-podcast-directory-search.md` (#442) — External Podcast Directory Search via iTunes Search API

**Test Areas**:
- Happy path: parses iTunes JSON response into `[DirectorySearchResult]`
- Filters results that lack a valid `feedUrl` field
- URL construction: verifies `term`, `media=podcast`, `entity=podcast`, `limit` parameters
- `DirectorySearchResult.toPodcast()` mapping (title, author, artwork, feedURL)
- Error cases: `.invalidQuery` (empty/whitespace), `.httpError(429)`, `.decodingError`, `.networkError`

### PodcastIndexSearchProviderTests.swift

**Purpose**: Validate `PodcastIndexSearchProvider` against a mock `URLSession`.

**Specifications Covered**: `spec/442-external-podcast-directory-search.md` (#442) — External Podcast Directory Search via PodcastIndex

**Test Areas**:
- Failable `init?(apiKey:apiSecret:urlSession:)` — returns `nil` for missing or empty keys
- Successful init with valid keys
- Happy path: parses PodcastIndex JSON response into `[DirectorySearchResult]`
- Filters results without a feed URL
- SHA-1 auth headers (per PodcastIndex spec): `X-Auth-Key`, `X-Auth-Date`, `Authorization` (40-char SHA-1 hex)
- Error cases: `.invalidQuery`, `.httpError(401)`, `.httpError(429)`, `.decodingError`, `.networkError`

### AggregateSearchProviderTests.swift

**Purpose**: Validate `AggregateSearchProvider` multi-provider fan-out and merge logic.

**Specifications Covered**: `spec/442-external-podcast-directory-search.md` (#442) — Graceful degradation and result deduplication

**Test Areas**:
- Empty provider list → returns empty array (no throw)
- Merges results from two providers (concatenation before dedup)
- Deduplicates by `feedURL` (first provider's result wins on collision)
- Absorbs a failing provider gracefully (partial results returned)
- Throws only when **all** providers fail (first error propagated)
- Single-provider passthrough

## Coverage Matrix

| Class | Unit Tests | Error Cases | Auth/Headers |
| --- | --- | --- | --- |
| `ITunesSearchProvider` | ✅ | ✅ | N/A (no auth) |
| `PodcastIndexSearchProvider` | ✅ | ✅ | ✅ |
| `AggregateSearchProvider` | ✅ | ✅ | N/A (delegates) |
| `PodcastDirectorySearching` (protocol) | Via implementations | — | — |

## Running Tests

```bash
# All SearchDomain package tests (via swift test directly)
cd Packages/SearchDomain && swift test

# Or via the test runner using a manifest-mapped source file
./scripts/run-xcode-tests.sh Packages/SearchDomain/Sources/SearchDomain/ITunesSearchProvider.swift
```
