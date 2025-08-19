# Global Application Settings

## Table of Contents
- [Description](#description)
- [Background](#background)
- [Configuring Default Playback Settings](#configuring-default-playback-settings)
- [Setting Global Download and Update Frequencies](#setting-global-download-and-update-frequencies)
- [Managing Global Cleanup Policies](#managing-global-cleanup-policies)
- [Configuring Cloud Backup Defaults (iCloud, Google Drive, Dropbox, etc.)](#configuring-cloud-backup-defaults-icloud-google-drive-dropbox-etc)
- [Adjusting Ad Display Preferences (Free Version)](#adjusting-ad-display-preferences-free-version)
- [Toggling CarPlay Layout Mode](#toggling-carplay-layout-mode)
- [Managing Notification Settings](#managing-notification-settings)
- [Configuring User Interface Display Options](#configuring-user-interface-display-options)
- [Handling Network Restrictions](#handling-network-restrictions)
- [Managing RSS Feed Customization](#managing-rss-feed-customization)
- [Accessing TestFlight Beta Program](#accessing-testflight-beta-program)
- [Protecting App with Face ID/Touch ID/Passcode](#protecting-app-with-face-idtouch-idpasscode)
- [Performing Local Backup and Restore](#performing-local-backup-and-restore)
- [Managing Confirmation Dialogs](#managing-confirmation-dialogs)
- [Resetting All Settings to Default](#resetting-all-settings-to-default)
- [Additional Settings Capabilities](#additional-settings-capabilities)

**Description:** Users can configure various default behaviors and preferences that apply across the entire application, unless overridden by podcast-specific settings. Designed for iPhone/iOS conventions. Users can choose from available integrations for backup and sync (e.g., iCloud, Google Drive, Dropbox).

## Background
- **Given:** App is launched on iPhone.
- **And:** In "Settings" section.

## Scenarios

### Configuring Default Playback Settings
- **Given:** User is in "Playback" settings.
- **When:** Adjusts speed, skip, volume, media button control.
- **Then:** Defaults are applied to all episodes unless overridden.

### Setting Global Download and Update Frequencies
- **Given:** User is in "Download" and "Update" settings.
- **When:** Configures auto-download, update frequency, storage folder, Wi-Fi only.
- **Then:** App follows these rules for downloads and updates.

### Managing Global Cleanup Policies
- **Given:** User is in "Automatic Cleanup" settings.
- **When:** Enables cleanup rules, recycle bin.
- **Then:** App manages episode deletion as configured.

### Configuring Cloud Backup Defaults (iCloud, Google Drive, Dropbox, etc.)
- **Given:** User is in "Cloud Backup" settings.
- **When:** Signs into iCloud, Google Drive, Dropbox, or other supported service.
- **Then:** Data is backed up automatically using the selected service.

### Adjusting Ad Display Preferences (Free Version)
- **Given:** User is in "Ads" or "Support" settings.
- **When:** Chooses ad display type.
- **Then:** Ads are shown per preference.

### Toggling CarPlay Layout Mode
- **Given:** User is in "Settings" menu.
- **When:** Toggles "CarPlay Layout".
- **Then:** UI switches to car-friendly layout for Apple CarPlay.

### Managing Notification Settings
- **Given:** User is in "Notifications" settings.
- **When:** Enables/disables notifications, customizes sound/vibration/priority.
- **Then:** Notifications are delivered per preferences using iOS notification system.

### Configuring User Interface Display Options
- **Given:** User is in "Display" or "User Interface" settings.
- **When:** Changes theme, tabs, layout, colors, font size.
- **Then:** App appearance updates, supporting iOS dark/light mode.

### Handling Network Restrictions
- **Given:** User is in "Network" settings.
- **When:** Enables "Wi-Fi only" for streaming/downloading.
- **Then:** App restricts network usage as configured.

### Managing RSS Feed Customization
- **Given:** User has added an RSS feed.
- **When:** Configures parsing/filter options.
- **Then:** Feed is processed per settings.

### Accessing TestFlight Beta Program
- **Given:** User wants early access to features.
- **When:** Joins TestFlight beta program.
- **Then:** Receives beta updates via TestFlight.

### Protecting App with Face ID/Touch ID/Passcode
- **Given:** User wants to secure app.
- **When:** Enables Face ID, Touch ID, or passcode protection.
- **Then:** App requires biometric or passcode to open.

### Performing Local Backup and Restore
- **Given:** User wants local backup.
- **When:** Creates backup or restores from file or iCloud.
- **Then:** Data is saved or restored.

### Managing Confirmation Dialogs
- **Given:** User wants to control prompts.
- **When:** Enables/disables confirmation dialogs.
- **Then:** Prompts are shown or suppressed per preference.

### Resetting All Settings to Default
- **Given:** User wants to revert settings.
- **When:** Uses "Reset Settings".
- **Then:** All settings are reset to default.

## Additional Settings Capabilities

### OPML Export
- **Given:** User wants to back up or migrate podcast subscriptions.
- **When:** Selects "Export OPML" in settings.
- **Then:** App generates and saves an OPML file containing all subscriptions.

### Apple Watch Support
- **Given:** User has an Apple Watch paired with their iPhone.
- **When:** Opens the Podcast Addict app on Apple Watch.
- **Then:** Can view and control global settings, quick actions, and notifications.

### Notification Actions
- **Given:** User receives a podcast notification on iOS.
- **When:** Interacts with the notification.
- **Then:** Can play, skip, or mark episodes as played directly from the notification.

### Siri and Shortcuts Integration
- **Given:** User wants to trigger global actions via voice or automation.
- **When:** Configures Siri or iOS Shortcuts for global actions.
- **Then:** Can trigger actions (play latest, subscribe, update all, etc.) via Siri or Shortcuts.

### Smart Episode Management
- **Given:** User wants automated global episode management.
- **When:** Enables auto-archive, auto-delete played, or smart cleanup rules in settings.
- **Then:** Episodes are managed automatically according to preferences.

### Custom Notification Sounds Per Podcast
- **Given:** User wants custom notification sounds for podcasts.
- **When:** Sets custom sound in notification settings for a podcast.
- **Then:** Notifications use the selected sound for that podcast.

### Smart Recommendations
- **Given:** User has a listening history in the app.
- **When:** Navigates to the recommendations section or receives a suggestion.
- **Then:** App displays personalized podcast and episode recommendations based on history and preferences.

### Advanced Search
- **Given:** User wants to search across all podcasts, episodes, and show notes.
- **When:** Uses unified search interface.
- **Then:** Results include podcasts, episodes, and show notes.

### Parental Controls and Content Filters
- **Given:** User wants to restrict explicit content or set parental controls.
- **When:** Enables parental controls or sets content filters in settings.
- **Then:** Explicit podcasts/episodes are hidden or restricted according to preferences.

### Apple ID Sign-In and iCloud Sync
- **Given:** User wants to sync global settings across devices.
- **When:** Signs in with Apple ID and enables iCloud sync.
- **Then:** Global settings are synced automatically across all devices.

### In-App Help and Support
- **Given:** User needs help or wants to provide feedback.
- **When:** Accesses the help/support section in the app.
- **Then:** Can view FAQ, contact support, and submit feedback directly.

### Accessibility for Global Settings
- **Given:** User has accessibility needs (e.g., uses VoiceOver, prefers large text, needs high contrast).
- **When:** Uses global settings features in the app.
- **Then:** All controls and features are fully compatible with VoiceOver, Dynamic Type, and high-contrast color schemes.

### Per-Podcast Override for Global Settings
- **Given:** User wants to override global settings for a specific podcast.
- **When:** Accesses the settings for that podcast.
- **Then:** Can adjust playback, download, notification, and display settings specifically for that podcast.

### Data Usage Controls
- **Given:** User wants to manage data usage for downloads and updates.
- **When:** Configures data usage settings in the app.
- **Then:** Can restrict downloads to Wi-Fi, set auto-download limits, and manage cellular data usage.

### Statistics and Listening History Export
- **Given:** User wants to export listening statistics and history.
- **When:** Selects export option in statistics or history section.
- **Then:** Data is exported in standard formats (CSV, JSON).

### Privacy Options
- **Given:** User wants to manage privacy-related preferences.
- **When:** Accesses privacy settings in the app.
- **Then:** Can clear search history, reset app data, and manage other privacy options.

### Language and Localization Settings
- **Given:** User wants to change the app's language or regional settings.
- **When:** Selects preferred language or region in language and localization settings.
- **Then:** App interface and content are displayed in the selected language and format.

### Advanced Notification Controls
- **Given:** User wants detailed control over notification settings.
- **When:** Accesses advanced notification settings for podcasts and episodes.
- **Then:** Can configure per-podcast notification settings, episode release alerts, download completion notifications, and custom notification sounds.

### Backup and Restore Settings
- **Given:** User wants to back up or restore app settings and data.
- **When:** Selects manual or scheduled backup/restore options.
- **Then:** App settings and data are backed up to or restored from the selected location (local, iCloud).

### Customizable Skip Intervals
- **Given:** User wants to customize skip intervals for playback.
- **When:** Sets custom skip forward/backward intervals in playback settings.
- **Then:** Playback skips are adjusted according to the custom intervals.

### Sleep Timer Options
- **Given:** User wants to use a sleep timer for playback.
- **When:** Configures sleep timer settings (e.g., auto-pause at episode end, shake to reset, custom durations).
- **Then:** Playback behavior follows the sleep timer configuration.

### Integration Settings
- **Given:** User wants to configure integration with external players or cloud services.
- **When:** Accesses integration settings in the app.
- **Then:** Can customize external player integration, cloud service connections, and widget settings using iOS features.
