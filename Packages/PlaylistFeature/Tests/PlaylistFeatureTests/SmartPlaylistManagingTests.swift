import XCTest
import CoreModels
@testable import PlaylistFeature

final class SmartPlaylistManagingTests: XCTestCase {

    // MARK: - Helpers

    private func makeManager(
        initialSmartPlaylists: [SmartEpisodeListV2] = SmartEpisodeListV2.builtInSmartLists
    ) -> InMemorySmartPlaylistManager {
        InMemorySmartPlaylistManager(initialSmartPlaylists: initialSmartPlaylists)
    }

    private func makeCustomSmartPlaylist(
        id: String = UUID().uuidString,
        name: String = "Custom List",
        rules: SmartListRuleSet = SmartListRuleSet(rules: [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
        ])
    ) -> SmartEpisodeListV2 {
        SmartEpisodeListV2(id: id, name: name, rules: rules)
    }

    // MARK: - All Smart Playlists

    func testAllSmartPlaylistsReturnsSystemFirst() {
        let manager = makeManager()
        let all = manager.allSmartPlaylists()
        XCTAssertFalse(all.isEmpty)

        // System-generated should come first
        let firstNonSystem = all.firstIndex { !$0.isSystemGenerated }
        let lastSystem = all.lastIndex { $0.isSystemGenerated }
        if let firstNS = firstNonSystem, let lastS = lastSystem {
            XCTAssertGreaterThan(firstNS, lastS)
        }
    }

    func testAllSmartPlaylistsSortedByName() {
        let manager = makeManager()
        let all = manager.allSmartPlaylists()
        let builtIn = all.filter(\.isSystemGenerated)

        // Built-in should be alphabetically sorted among themselves
        for i in 1..<builtIn.count {
            XCTAssertLessThanOrEqual(builtIn[i - 1].name, builtIn[i].name)
        }
    }

    // MARK: - Built-in vs Custom Partitioning

    func testBuiltInSmartPlaylistsOnlyReturnsSystem() {
        let manager = makeManager()
        let builtIn = manager.builtInSmartPlaylists()
        XCTAssertTrue(builtIn.allSatisfy(\.isSystemGenerated))
    }

    func testCustomSmartPlaylistsOnlyReturnsNonSystem() {
        let manager = makeManager()
        let custom = manager.customSmartPlaylists()
        XCTAssertTrue(custom.isEmpty)

        // Add a custom one
        let customList = makeCustomSmartPlaylist()
        manager.createSmartPlaylist(customList)
        let result = manager.customSmartPlaylists()
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.allSatisfy { !$0.isSystemGenerated })
    }

    // MARK: - CRUD

    func testCreateSmartPlaylist() {
        let manager = makeManager()
        let initial = manager.allSmartPlaylists().count

        let custom = makeCustomSmartPlaylist()
        manager.createSmartPlaylist(custom)

        XCTAssertEqual(manager.allSmartPlaylists().count, initial + 1)
    }

    func testCreateSmartPlaylistRejectsDuplicateId() {
        let manager = makeManager()
        let custom = makeCustomSmartPlaylist(id: "dup-1")
        manager.createSmartPlaylist(custom)
        manager.createSmartPlaylist(custom)

        XCTAssertEqual(manager.customSmartPlaylists().count, 1)
    }

    func testFindSmartPlaylistById() {
        let manager = makeManager()
        let custom = makeCustomSmartPlaylist(id: "find-me")
        manager.createSmartPlaylist(custom)

        let found = manager.findSmartPlaylist(id: "find-me")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, "find-me")
    }

    func testFindSmartPlaylistReturnsNilForMissingId() {
        let manager = makeManager()
        let found = manager.findSmartPlaylist(id: "nonexistent")
        XCTAssertNil(found)
    }

    func testUpdateSmartPlaylist() {
        let manager = makeManager()
        let custom = makeCustomSmartPlaylist(id: "update-me", name: "Old Name")
        manager.createSmartPlaylist(custom)

        let updated = custom.withName("New Name")
        manager.updateSmartPlaylist(updated)

        let result = manager.findSmartPlaylist(id: "update-me")
        XCTAssertEqual(result?.name, "New Name")
    }

    func testUpdateNonexistentSmartPlaylistIsNoOp() {
        let manager = makeManager()
        let ghost = makeCustomSmartPlaylist(id: "ghost")
        // Don't create it, just try to update
        manager.updateSmartPlaylist(ghost)
        XCTAssertNil(manager.findSmartPlaylist(id: "ghost"))
    }

    func testDeleteCustomSmartPlaylist() {
        let manager = makeManager()
        let custom = makeCustomSmartPlaylist(id: "del-me")
        manager.createSmartPlaylist(custom)

        manager.deleteSmartPlaylist(id: "del-me")
        XCTAssertNil(manager.findSmartPlaylist(id: "del-me"))
    }

    func testDeleteBuiltInSmartPlaylistIsBlocked() {
        let manager = makeManager()
        let builtInId = SmartEpisodeListV2.builtInSmartLists[0].id
        let countBefore = manager.builtInSmartPlaylists().count

        manager.deleteSmartPlaylist(id: builtInId)
        XCTAssertEqual(manager.builtInSmartPlaylists().count, countBefore)
    }

    // MARK: - Templates

    func testAvailableTemplatesReturnsBuiltInTemplates() {
        let manager = makeManager()
        let templates = manager.availableTemplates()
        XCTAssertFalse(templates.isEmpty)
        XCTAssertEqual(templates.count, SmartListRuleTemplate.builtInTemplates.count)
    }

    // MARK: - Evaluation

    func testEvaluateSmartPlaylistFiltersEpisodes() {
        let manager = makeManager()

        let unplayedList = SmartEpisodeListV2(
            name: "Unplayed Only",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ])
        )

        let episodes = [
            Episode(id: "ep-1", title: "Played", podcastID: "p1", podcastTitle: "P1", isPlayed: true),
            Episode(id: "ep-2", title: "Unplayed", podcastID: "p1", podcastTitle: "P1", isPlayed: false),
        ]

        let result = manager.evaluateSmartPlaylist(unplayedList, allEpisodes: episodes)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "ep-2")
    }

    func testEvaluateRespectsMaxEpisodes() {
        let manager = makeManager()

        let limitedList = SmartEpisodeListV2(
            name: "Limited",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ]),
            maxEpisodes: 1
        )

        let episodes = [
            Episode(id: "ep-1", title: "A", podcastID: "p1", podcastTitle: "P1", isPlayed: false),
            Episode(id: "ep-2", title: "B", podcastID: "p1", podcastTitle: "P1", isPlayed: false),
            Episode(id: "ep-3", title: "C", podcastID: "p1", podcastTitle: "P1", isPlayed: false),
        ]

        let result = manager.evaluateSmartPlaylist(limitedList, allEpisodes: episodes)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Builder Methods

    func testWithNameUpdatesName() {
        let original = makeCustomSmartPlaylist(name: "Original")
        let updated = original.withName("Updated")
        XCTAssertEqual(updated.name, "Updated")
        XCTAssertEqual(updated.id, original.id)
    }

    func testWithDescriptionUpdatesDescription() {
        let original = makeCustomSmartPlaylist()
        let updated = original.withDescription("New description")
        XCTAssertEqual(updated.description, "New description")
    }

    func testWithRulesUpdatesRules() {
        let original = makeCustomSmartPlaylist()
        let newRules = SmartListRuleSet(rules: [
            SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(3600))
        ], logic: .or)
        let updated = original.withRules(newRules)
        XCTAssertEqual(updated.rules.logic, .or)
        XCTAssertEqual(updated.rules.rules[0].type, .duration)
    }

    func testWithSortByUpdatesSortBy() {
        let original = makeCustomSmartPlaylist()
        let updated = original.withSortBy(.duration)
        XCTAssertEqual(updated.sortBy, .duration)
    }

    func testWithMaxEpisodesUpdatesLimit() {
        let original = makeCustomSmartPlaylist()
        let updated = original.withMaxEpisodes(25)
        XCTAssertEqual(updated.maxEpisodes, 25)

        let cleared = updated.withMaxEpisodes(nil)
        XCTAssertNil(cleared.maxEpisodes)
    }

    func testWithAutoUpdateUpdatesFlag() {
        let original = makeCustomSmartPlaylist()
        let updated = original.withAutoUpdate(false)
        XCTAssertFalse(updated.autoUpdate)
    }

    func testWithRefreshIntervalUpdatesInterval() {
        let original = makeCustomSmartPlaylist()
        let updated = original.withRefreshInterval(900)
        XCTAssertEqual(updated.refreshInterval, 900)
    }

    func testBuilderMethodsUpdateLastUpdated() {
        let original = makeCustomSmartPlaylist()
        let before = original.lastUpdated

        // Small sleep to ensure time difference
        let updated = original.withName("Later")
        XCTAssertGreaterThanOrEqual(updated.lastUpdated, before)
    }

    func testBuilderMethodsPreserveId() {
        let original = makeCustomSmartPlaylist(id: "stable-id")
        XCTAssertEqual(original.withName("X").id, "stable-id")
        XCTAssertEqual(original.withDescription("X").id, "stable-id")
        XCTAssertEqual(original.withSortBy(.title).id, "stable-id")
        XCTAssertEqual(original.withMaxEpisodes(10).id, "stable-id")
        XCTAssertEqual(original.withAutoUpdate(false).id, "stable-id")
        XCTAssertEqual(original.withRefreshInterval(60).id, "stable-id")
    }
}
