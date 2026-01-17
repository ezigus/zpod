# Podcast Discovery and Subscription

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Subscribing to a New Podcast](#subscribing-to-a-new-podcast)
- [In-App Episode Search](#in-app-episode-search)
- [Organizing Podcasts into Folders/Categories](#organizing-podcasts-into-folderscategories)
- [Per-Podcast Update Frequency](#per-podcast-update-frequency)
- [Podcast Addict API Integration (iOS Shortcuts, Google Assistant)](#podcast-addict-api-integration-ios-shortcuts-google-assistant)
- [Importing Subscriptions via OPML](#importing-subscriptions-via-opml)
- [Exporting Subscriptions via OPML](#exporting-subscriptions-via-opml)
- [Browsing Popular Podcasts](#browsing-popular-podcasts)
- [Smart Recommendations](#smart-recommendations)
- [Advanced Search](#advanced-search)
- [Parental Controls and Content Filters](#parental-controls-and-content-filters)
- [Apple ID Sign-In and iCloud Sync](#apple-id-sign-in-and-icloud-sync)
- [Accessibility for Discovery Features](#accessibility-for-discovery-features)
- [Feed Parsing](#feed-parsing)
  - [Parsing Episode Audio Enclosure](#parsing-episode-audio-enclosure)
  - [Parsing Episode Duration](#parsing-episode-duration)
  - [Handling Missing Audio Enclosure](#handling-missing-audio-enclosure)

**Description:** Users can easily find and subscribe to a wide variety of podcasts, audiobooks, and other audio content, designed for iPhone/iOS conventions. Users can choose from available integrations for automation (e.g., iOS Shortcuts, Google Assistant).

## Background
- **Given:** The user has successfully launched the Podcast Addict app on iPhone.
- **And:** The user has an active internet connection.

## Scenarios

### Subscribing to a New Podcast
- **Given:** The user is viewing the main "Podcasts" screen or "Discover" section.
- **When:** The user taps the "+" (Add Podcast) button.
- **And:** Uses the search engine (keywords, category, episode title).
- **Then:** Selects a content item and taps "Subscribe".
- **And:** The podcast is added to "Subscriptions" and episodes are available.
- **And:** The subscription remains after closing and reopening the app.

### In-App Episode Search
- **Given:** The user is viewing a podcast's episode list.
- **When:** The user enters a search term in the episode search bar.
- **Then:** The app filters and displays only matching episodes within that podcast.

### Organizing Podcasts into Folders/Categories
- **Given:** The user has multiple podcasts in their library.
- **When:** The user creates folders or assigns categories to podcasts.
- **Then:** The user can view, filter, and manage podcasts by folder/category.

### Per-Podcast Update Frequency
- **Given:** The user wants to control how often a podcast feed is updated.
- **When:** The user sets a custom update interval for a specific podcast.
- **Then:** The app checks for new episodes at the specified interval for that podcast.

### Podcast Addict API Integration (iOS Shortcuts, Google Assistant)
- **Given:** The user has external automation apps (e.g., iOS Shortcuts, Google Assistant).
- **When:** The user enables API integration in settings.
- **Then:** External apps can trigger actions (e.g., subscribe, play, update) via Podcast Addict's automation support.

### Importing Subscriptions via OPML
- **Given:** The user has an OPML file with subscriptions.
- **When:** Selects "OPML import" and chooses a file.
- **Then:** All valid feeds are added to subscriptions.

### Exporting Subscriptions via OPML
- **Given:** User wants to back up or migrate podcast subscriptions.
- **When:** Selects "Export OPML" in settings.
- **Then:** App generates and saves an OPML file containing all subscriptions.

### Browsing Popular Podcasts
- **Given:** The user is in "Discover".
- **When:** Accesses "Popular Podcasts" or "Browse Categories" and applies language filters.
- **Then:** Sees a curated, filtered list and can subscribe directly.

### Smart Recommendations
- **Given:** User has a listening history in the app.
- **When:** Navigates to the recommendations section or receives a suggestion.
- **Then:** App displays personalized podcast and episode recommendations based on history and preferences.

### Advanced Search
- **Given:** User wants to search across all podcasts and episodes.
- **When:** Uses unified search interface.
- **Then:** Results include podcasts, episodes, and show notes.

### Parental Controls and Content Filters
- **Given:** User wants to restrict explicit content or set parental controls.
- **When:** Enables parental controls or sets content filters in settings.
- **Then:** Explicit podcasts/episodes are hidden or restricted according to preferences.

### Apple ID Sign-In and iCloud Sync
- **Given:** User wants to sync subscriptions and discovery preferences across devices.
- **When:** Signs in with Apple ID and enables iCloud sync.
- **Then:** Subscriptions and preferences are synced automatically across all devices.

### Accessibility for Discovery Features
- **Given:** User has accessibility needs (e.g., uses VoiceOver, prefers large text, needs high contrast).
- **When:** Uses discovery features in the app.
- **Then:** All controls and features are fully compatible with VoiceOver, Dynamic Type, and high-contrast color schemes.

### Adding Podcast by Direct RSS Feed URL
- **Given:** The user knows the RSS feed URL.
- **When:** Selects "Add by RSS Feed URL" and enters the URL.
- **Then:** The app validates and adds the podcast.

---

## Feed Parsing

These scenarios define how podcast RSS feeds are parsed to extract episode metadata.

### Parsing Episode Audio Enclosure
- **Given:** A podcast RSS feed contains episodes with `<enclosure>` elements.
- **When:** The feed is parsed.
- **Then:** Each episode's audioURL is populated from the enclosure URL attribute.
- **And:** The URL is validated as parseable.

### Parsing Episode Duration
- **Given:** A podcast RSS feed contains `<itunes:duration>` elements.
- **When:** The feed is parsed.
- **Then:** Each episode's duration is extracted.
- **And:** Duration in seconds format (e.g., "3600") is parsed correctly.
- **And:** Duration in HH:MM:SS format (e.g., "1:00:00") is parsed correctly.

### Handling Missing Audio Enclosure
- **Given:** An RSS feed episode is missing the `<enclosure>` element.
- **When:** The feed is parsed.
- **Then:** The episode is created with audioURL = nil.
- **And:** A warning is logged.
- **And:** No error is thrown.
