import XCTest
import CoreModels
@testable import PlaylistFeature

@MainActor
final class SmartPlaylistViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(
        initialSmartPlaylists: [SmartEpisodeListV2] = SmartEpisodeListV2.builtInSmartLists,
        allEpisodes: [Episode] = []
    ) -> SmartPlaylistViewModel {
        let manager = InMemorySmartPlaylistManager(
            initialSmartPlaylists: initialSmartPlaylists
        )
        return SmartPlaylistViewModel(
            manager: manager,
            allEpisodesProvider: { allEpisodes }
        )
    }

    private func makeSampleEpisodes() -> [Episode] {
        [
            Episode(
                id: "ep-1",
                title: "News Roundup",
                podcastID: "pod-1",
                podcastTitle: "Daily News",
                isPlayed: false,
                pubDate: Date().addingTimeInterval(-3600),
                duration: 1800,
                description: "Latest news",
                downloadStatus: .downloaded
            ),
            Episode(
                id: "ep-2",
                title: "Interview with Expert",
                podcastID: "pod-2",
                podcastTitle: "Tech Talk",
                isPlayed: true,
                pubDate: Date().addingTimeInterval(-86400),
                duration: 3600,
                description: "Deep dive interview",
                downloadStatus: .notDownloaded
            ),
            Episode(
                id: "ep-3",
                title: "Quick Tips",
                podcastID: "pod-1",
                podcastTitle: "Daily News",
                isPlayed: false,
                pubDate: Date().addingTimeInterval(-7200),
                duration: 600,
                description: "Short tips segment",
                downloadStatus: .downloaded
            ),
        ]
    }

    // MARK: - Initialization

    func testInitLoadsBuiltInSmartPlaylists() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.smartPlaylists.isEmpty)
        XCTAssertEqual(vm.builtInPlaylists.count, SmartEpisodeListV2.builtInSmartLists.count)
    }

    func testInitDefaultSheetStateIsFalse() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isShowingCreateSheet)
        XCTAssertNil(vm.editingSmartPlaylist)
        XCTAssertNil(vm.errorMessage)
    }

    func testBuiltInAndCustomArePartitioned() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.builtInPlaylists.allSatisfy(\.isSystemGenerated))
        XCTAssertTrue(vm.customPlaylists.isEmpty)
    }

    // MARK: - Create Smart Playlist

    func testCreateSmartPlaylistAddsToCustomList() {
        let vm = makeViewModel()
        let initialCount = vm.smartPlaylists.count

        vm.createSmartPlaylist(
            name: "My Custom List",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ])
        )

        XCTAssertEqual(vm.smartPlaylists.count, initialCount + 1)
        XCTAssertEqual(vm.customPlaylists.count, 1)
        XCTAssertEqual(vm.customPlaylists[0].name, "My Custom List")
    }

    func testCreateSmartPlaylistTrimsWhitespace() {
        let vm = makeViewModel()

        vm.createSmartPlaylist(
            name: "  Trimmed Name  ",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ])
        )

        XCTAssertEqual(vm.customPlaylists[0].name, "Trimmed Name")
    }

    func testCreateSmartPlaylistIgnoresEmptyName() {
        let vm = makeViewModel()
        let initialCount = vm.smartPlaylists.count

        vm.createSmartPlaylist(
            name: "   ",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ])
        )

        XCTAssertEqual(vm.smartPlaylists.count, initialCount)
    }

    func testCreateSmartPlaylistWithAllOptions() {
        let vm = makeViewModel()

        vm.createSmartPlaylist(
            name: "Full Options",
            description: "A detailed description",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(1800))
            ]),
            sortBy: .duration,
            maxEpisodes: 25,
            autoUpdate: false,
            refreshInterval: 600
        )

        let created = vm.customPlaylists[0]
        XCTAssertEqual(created.name, "Full Options")
        XCTAssertEqual(created.description, "A detailed description")
        XCTAssertEqual(created.sortBy, .duration)
        XCTAssertEqual(created.maxEpisodes, 25)
        XCTAssertFalse(created.autoUpdate)
        XCTAssertEqual(created.refreshInterval, 600)
    }

    // MARK: - Create from Template

    func testCreateFromTemplateAddsSmartPlaylist() {
        let vm = makeViewModel()
        let initialCount = vm.smartPlaylists.count

        let template = SmartListRuleTemplate.builtInTemplates[0]
        vm.createFromTemplate(template)

        XCTAssertEqual(vm.smartPlaylists.count, initialCount + 1)
        XCTAssertEqual(vm.customPlaylists[0].name, template.name)
    }

    // MARK: - Update Smart Playlist

    func testUpdateSmartPlaylistChangesName() {
        let vm = makeViewModel()
        vm.createSmartPlaylist(
            name: "Old Name",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ])
        )

        let original = vm.customPlaylists[0]
        let updated = original.withName("New Name")
        vm.updateSmartPlaylist(updated)

        XCTAssertEqual(vm.customPlaylists[0].name, "New Name")
    }

    func testUpdateSmartPlaylistChangesRules() {
        let vm = makeViewModel()
        vm.createSmartPlaylist(
            name: "Test",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ])
        )

        let original = vm.customPlaylists[0]
        let newRules = SmartListRuleSet(rules: [
            SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(3600))
        ], logic: .or)
        let updated = original.withRules(newRules)
        vm.updateSmartPlaylist(updated)

        XCTAssertEqual(vm.customPlaylists[0].rules.logic, .or)
        XCTAssertEqual(vm.customPlaylists[0].rules.rules.count, 1)
        XCTAssertEqual(vm.customPlaylists[0].rules.rules[0].type, .duration)
    }

    // MARK: - Delete Smart Playlist

    func testDeleteCustomSmartPlaylist() {
        let vm = makeViewModel()
        vm.createSmartPlaylist(
            name: "To Delete",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ])
        )

        XCTAssertEqual(vm.customPlaylists.count, 1)
        vm.deleteSmartPlaylist(id: vm.customPlaylists[0].id)
        XCTAssertTrue(vm.customPlaylists.isEmpty)
    }

    func testDeleteBuiltInSmartPlaylistIsBlocked() {
        let vm = makeViewModel()
        let builtInCount = vm.builtInPlaylists.count

        vm.deleteSmartPlaylist(id: vm.builtInPlaylists[0].id)
        XCTAssertEqual(vm.builtInPlaylists.count, builtInCount)
    }

    func testDeleteAtOffsetsRemovesCorrectCustomPlaylist() {
        let vm = makeViewModel()
        vm.createSmartPlaylist(
            name: "First Custom",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ])
        )
        vm.createSmartPlaylist(
            name: "Second Custom",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.played))
            ])
        )

        XCTAssertEqual(vm.customPlaylists.count, 2)
        vm.deleteSmartPlaylist(at: IndexSet(integer: 0))
        XCTAssertEqual(vm.customPlaylists.count, 1)
    }

    // MARK: - Duplicate Smart Playlist

    func testDuplicateCreatesACopy() {
        let vm = makeViewModel()
        vm.createSmartPlaylist(
            name: "Original",
            description: "A smart playlist",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(1800))
            ]),
            maxEpisodes: 30
        )

        let original = vm.customPlaylists[0]
        vm.duplicateSmartPlaylist(original)

        XCTAssertEqual(vm.customPlaylists.count, 2)
        let copy = vm.customPlaylists.first { $0.id != original.id }
        XCTAssertNotNil(copy)
        XCTAssertEqual(copy?.name, "Original Copy")
        XCTAssertEqual(copy?.maxEpisodes, 30)
        XCTAssertNotEqual(copy?.id, original.id)
    }

    func testDuplicateBuiltInIsBlocked() {
        let vm = makeViewModel()
        let builtIn = vm.builtInPlaylists[0]
        let totalCount = vm.smartPlaylists.count

        vm.duplicateSmartPlaylist(builtIn)
        XCTAssertEqual(vm.smartPlaylists.count, totalCount)
    }

    // MARK: - Episode Evaluation

    func testEpisodesForSmartPlaylistFilters() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        // "Recent Unplayed" built-in list filters to unplayed + recent
        let recentUnplayed = vm.builtInPlaylists.first { $0.id == "recent_unplayed" }
        XCTAssertNotNil(recentUnplayed)

        if let recentUnplayed {
            let result = vm.episodes(for: recentUnplayed)
            // ep-1 and ep-3 are unplayed and recent; ep-2 is played
            XCTAssertTrue(result.allSatisfy { !$0.isPlayed })
        }
    }

    func testTotalDurationForSmartPlaylist() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        let recentUnplayed = vm.builtInPlaylists.first { $0.id == "recent_unplayed" }
        XCTAssertNotNil(recentUnplayed)

        if let recentUnplayed {
            let duration = vm.totalDuration(for: recentUnplayed)
            XCTAssertNotNil(duration)
            // Should sum durations of matching episodes
            if let duration {
                XCTAssertGreaterThan(duration, 0)
            }
        }
    }

    func testTotalDurationReturnsNilForNoMatches() {
        // No episodes provided
        let vm = makeViewModel(allEpisodes: [])

        let recentUnplayed = vm.builtInPlaylists.first { $0.id == "recent_unplayed" }
        XCTAssertNotNil(recentUnplayed)

        if let recentUnplayed {
            let duration = vm.totalDuration(for: recentUnplayed)
            XCTAssertNil(duration)
        }
    }

    // MARK: - Preview Episodes

    func testPreviewEpisodesForRules() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        let rules = SmartListRuleSet(rules: [
            SmartListRule(type: .downloadStatus, comparison: .equals, value: .downloadStatus(.downloaded))
        ])

        let preview = vm.previewEpisodes(for: rules)
        XCTAssertTrue(preview.allSatisfy { $0.downloadStatus == .downloaded })
    }

    func testPreviewEpisodesRespectsMaxEpisodes() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        let rules = SmartListRuleSet(rules: [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
        ])

        let preview = vm.previewEpisodes(for: rules, maxEpisodes: 1)
        XCTAssertEqual(preview.count, 1)
    }

    // MARK: - Templates

    func testAvailableTemplatesReturnsBuiltInTemplates() {
        let vm = makeViewModel()
        let templates = vm.availableTemplates()
        XCTAssertFalse(templates.isEmpty)
        XCTAssertEqual(templates.count, SmartListRuleTemplate.builtInTemplates.count)
    }

    func testTemplatesByCategoryGroupsCorrectly() {
        let vm = makeViewModel()
        let grouped = vm.templatesByCategory()
        XCTAssertFalse(grouped.isEmpty)
        // Verify at least recent and duration categories exist
        XCTAssertNotNil(grouped[.recent])
        XCTAssertNotNil(grouped[.duration])
    }

    // MARK: - Playback Callbacks

    func testOnPlayAllCallbackInvoked() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)
        var invokedEpisodes: [Episode]?
        vm.onPlayAll = { eps in invokedEpisodes = eps }

        vm.onPlayAll?(episodes)
        XCTAssertNotNil(invokedEpisodes)
        XCTAssertEqual(invokedEpisodes?.count, episodes.count)
    }

    func testOnShuffleCallbackInvoked() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)
        var invokedEpisodes: [Episode]?
        vm.onShuffle = { eps in invokedEpisodes = eps }

        vm.onShuffle?(episodes)
        XCTAssertNotNil(invokedEpisodes)
    }
}
