# Main Application Test Summary

This document outlines the testing structure and approach for the main zpod application, separate from package-level tests.

## Test Categories

### 1. Unit Tests (`zpodTests/`)
Tests that verify individual components and their interactions within the main application.

#### Playback Controls Tests (`PlaybackControlTests.swift`)
**Specifications Covered**: `spec/playback.md`
- Tests episode playback functionality
- Validates custom speed controls (0.8x-5.0x)
- Verifies skip silence and volume boost features
- Tests marking episodes as played/unplayed
- Covers seeking and position management

**Current Status**: Refactored from Issue03AdvancedControlsTests.swift

#### Playlist Management Tests (`PlaylistManagementTests.swift`)
**Specifications Covered**: `spec/content.md` - Playlist sections
- Tests manual playlist creation, modification, and deletion
- Validates smart playlist criteria and filtering
- Tests continuous playback and shuffle functionality
- Covers playlist ordering and episode management

**Current Status**: Refactored from Issue06PlaylistTests.swift

#### Content Organization Tests (`ContentOrganizationTests.swift`)
**Specifications Covered**: `spec/discovery.md` - Organization sections
- Tests folder hierarchy management
- Validates tag assignment and filtering
- Tests podcast categorization
- Covers search within organized content

**Current Status**: Refactored from Issue07FolderTagTests.swift

#### Podcast Management Tests (`PodcastManagementTests.swift`)
**Specifications Covered**: `spec/discovery.md` - Podcast management
- Tests CRUD operations for podcasts
- Validates subscription management
- Tests feed parsing integration
- Covers podcast metadata handling

**Current Status**: Refactored from PodcastManagerCRUDTests.swift

### 2. UI Tests (`zpodUITests/`)
Tests that verify user interface behavior and user workflows.

#### Core UI Navigation Tests (`CoreUINavigationTests.swift`)
**Specifications Covered**: `spec/ui.md` - Navigation sections
- Tests main navigation flow between screens
- Validates tab bar and navigation bar behavior
- Tests accessibility compliance
- Covers keyboard navigation and VoiceOver support

#### Playback UI Tests (`PlaybackUITests.swift`)
**Specifications Covered**: `spec/ui.md` - Playback interface sections
- Tests player interface controls
- Validates now playing screen functionality
- Tests CarPlay integration
- Covers lock screen and control center integration

#### Content Discovery UI Tests (`ContentDiscoveryUITests.swift`)
**Specifications Covered**: `spec/ui.md` - Search and discovery sections
- Tests search interface and results
- Validates browse and discovery screens
- Tests filtering and sorting UI
- Covers subscription management interface

### 3. Integration Tests (`IntegrationTests/`)
Tests that verify end-to-end workflows and cross-component interactions.

#### Core Workflow Integration Tests (`CoreWorkflowIntegrationTests.swift`)
**Specifications Covered**: Cross-specification workflows
- Tests complete user journeys (subscribe → organize → play)
- Validates data persistence across app sessions
- Tests synchronization between components
- Covers performance under realistic usage patterns

#### Platform Integration Tests (`PlatformIntegrationTests.swift`)
**Specifications Covered**: `spec/ui.md` - Platform-specific sections
- Tests CarPlay integration workflows
- Validates Apple Watch companion functionality
- Tests Siri and Shortcuts integration
- Covers background audio and notification handling

## Testing Principles

### Specification-Based Testing
All tests are organized around specifications rather than development issues. Each test file clearly maps to specification sections and validates the described behaviors.

### Test Isolation
- Each test uses isolated data and mock services
- Tests do not depend on external services or network connectivity
- Test data is cleaned up after each test run

### Given/When/Then Structure
All tests follow the Given/When/Then pattern to match the specification format and provide clear test intent.

### Coverage Focus
- **Unit Tests**: Focus on business logic and component behavior
- **UI Tests**: Focus on user workflows and interface compliance
- **Integration Tests**: Focus on end-to-end scenarios and component interactions

## Mock and Test Support

Tests use mock implementations from the TestSupport package for:
- Podcast management services
- Audio playback engines
- Network services
- Data persistence

## Performance and Reliability

- Tests include performance benchmarks for critical paths
- Tests validate error handling and edge cases
- Tests ensure accessibility compliance
- Tests verify memory management and resource cleanup