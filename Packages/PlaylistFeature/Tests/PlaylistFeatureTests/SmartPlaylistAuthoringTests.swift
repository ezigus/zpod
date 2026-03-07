import XCTest
import CoreModels
@testable import PlaylistFeature

@MainActor
final class SmartPlaylistAuthoringTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(allEpisodes: [Episode] = []) -> SmartPlaylistViewModel {
        let manager = InMemorySmartPlaylistManager(initialSmartPlaylists: SmartEpisodeListV2.builtInSmartLists)
        return SmartPlaylistViewModel(manager: manager, allEpisodesProvider: { allEpisodes })
    }

    private func makeSampleEpisodes() -> [Episode] {
        [
            Episode(
                id: "auth-ep-1",
                title: "Tech News",
                podcastID: "pod-tech",
                podcastTitle: "Tech Daily",
                isPlayed: false,
                pubDate: Date().addingTimeInterval(-3600),
                duration: 1800,
                description: "Technology updates",
                downloadStatus: .downloaded
            ),
            Episode(
                id: "auth-ep-2",
                title: "Science Bytes",
                podcastID: "pod-sci",
                podcastTitle: "Science Weekly",
                isPlayed: false,
                pubDate: Date().addingTimeInterval(-7200),
                duration: 3600,
                description: "Science roundup",
                downloadStatus: .notDownloaded
            ),
            Episode(
                id: "auth-ep-3",
                title: "History Hour",
                podcastID: "pod-hist",
                podcastTitle: "History Uncovered",
                isPlayed: true,
                pubDate: Date().addingTimeInterval(-86400),
                duration: 5400,
                description: "Historical tales",
                downloadStatus: .downloaded
            ),
            Episode(
                id: "auth-ep-4",
                title: "Quick Take",
                podcastID: "pod-tech",
                podcastTitle: "Tech Daily",
                isPlayed: false,
                pubDate: Date().addingTimeInterval(-1800),
                duration: 600,
                description: "Short tech update",
                downloadStatus: .downloaded
            ),
        ]
    }

    // MARK: - Create with Multiple Rules

    func testCreateWithMultipleRulesAndVerifyPreview() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        // AND: unplayed AND downloaded
        let rules = SmartListRuleSet(rules: [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed)),
            SmartListRule(type: .downloadStatus, comparison: .equals, value: .downloadStatus(.downloaded)),
        ], logic: .and)
        vm.createSmartPlaylist(name: "Unplayed & Downloaded", rules: rules)

        let created = vm.customPlaylists[0]
        let matching = vm.episodes(for: created)

        // auth-ep-1 (unplayed, downloaded), auth-ep-4 (unplayed, downloaded)
        // auth-ep-2 is unplayed but NOT downloaded; auth-ep-3 is played
        XCTAssertEqual(matching.count, 2)
        XCTAssertTrue(matching.allSatisfy { !$0.isPlayed })
        XCTAssertTrue(matching.allSatisfy { $0.downloadStatus == .downloaded })
    }

    // MARK: - Edit Rules Then Save

    func testEditRulesThenSaveUpdatesPlaylist() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        let initialRules = SmartListRuleSet(rules: [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed)),
        ])
        vm.createSmartPlaylist(name: "Unplayed", rules: initialRules)

        let original = vm.customPlaylists[0]
        // auth-ep-1, auth-ep-2, auth-ep-4 are unplayed
        XCTAssertEqual(vm.episodes(for: original).count, 3)

        // Tighten to: unplayed AND downloaded
        let newRules = SmartListRuleSet(rules: [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed)),
            SmartListRule(type: .downloadStatus, comparison: .equals, value: .downloadStatus(.downloaded)),
        ], logic: .and)
        vm.updateSmartPlaylist(original.withRules(newRules))

        let updated = vm.customPlaylists[0]
        XCTAssertEqual(updated.rules.rules.count, 2)
        // auth-ep-1 and auth-ep-4 match; auth-ep-2 is not downloaded
        XCTAssertEqual(vm.episodes(for: updated).count, 2)
    }

    // MARK: - Edit Metadata Preserves Rules

    func testEditNameAndDescriptionPreservesRules() {
        let vm = makeViewModel()

        let rules = SmartListRuleSet(rules: [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed)),
            SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(1800)),
        ], logic: .or)
        vm.createSmartPlaylist(name: "Original Name", description: "Old desc", rules: rules)

        let original = vm.customPlaylists[0]
        vm.updateSmartPlaylist(
            original
                .withName("New Name")
                .withDescription("New desc")
        )

        let saved = vm.customPlaylists[0]
        XCTAssertEqual(saved.name, "New Name")
        XCTAssertEqual(saved.description, "New desc")
        XCTAssertEqual(saved.rules.rules.count, 2)
        XCTAssertEqual(saved.rules.logic, .or)
    }

    // MARK: - Preview Accuracy: OR Logic

    func testPreviewAccuracyWithORLogic() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        // OR: unplayed OR downloaded
        let rules = SmartListRuleSet(rules: [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed)),
            SmartListRule(type: .downloadStatus, comparison: .equals, value: .downloadStatus(.downloaded)),
        ], logic: .or)
        let preview = vm.previewEpisodes(for: rules)

        // auth-ep-1: unplayed ✓, downloaded ✓
        // auth-ep-2: unplayed ✓, not downloaded
        // auth-ep-3: played, downloaded ✓
        // auth-ep-4: unplayed ✓, downloaded ✓
        XCTAssertEqual(preview.count, 4)
    }

    // MARK: - Preview Accuracy: Negated Rule

    func testPreviewAccuracyWithNegatedRule() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        // NOT played  →  unplayed episodes only
        let rules = SmartListRuleSet(rules: [
            SmartListRule(
                type: .playStatus,
                comparison: .equals,
                value: .episodeStatus(.played),
                isNegated: true
            ),
        ])
        let preview = vm.previewEpisodes(for: rules)

        XCTAssertTrue(preview.allSatisfy { !$0.isPlayed })
        // auth-ep-1, auth-ep-2, auth-ep-4 are unplayed
        XCTAssertEqual(preview.count, 3)
    }

    // MARK: - Template Application

    func testTemplateApplicationPopulatesAllFields() {
        let vm = makeViewModel()
        let templates = vm.availableTemplates()
        guard let template = templates.first else {
            XCTFail("Expected at least one built-in template")
            return
        }

        vm.createFromTemplate(template)

        XCTAssertEqual(vm.customPlaylists.count, 1)
        let created = vm.customPlaylists[0]
        XCTAssertEqual(created.name, template.name)
        XCTAssertFalse(created.rules.rules.isEmpty)
        XCTAssertFalse(created.isSystemGenerated)
    }

    // MARK: - Validator Integration

    /// Verify that the default form rule (play status = unplayed) passes validation —
    /// ensuring new playlists can always be saved immediately without user intervention.
    func testDefaultRulePassesValidation() {
        let defaultRule = SmartListRule(
            type: .playStatus,
            comparison: .equals,
            value: .episodeStatus(.unplayed)
        )
        if case .failure(let errors) = SmartListRuleValidator.validateAll([defaultRule]) {
            XCTFail("Default play-status rule should pass validation; got errors: \(errors.errors)")
        }
    }

    /// Verify that an empty-string podcast filter rule fails validation.
    ///
    /// The save button uses `SmartListRuleValidator.validateAll(rules)` to gate
    /// persistence, so invalid rules are blocked before reaching the ViewModel.
    func testEmptyStringPodcastRuleFailsValidation() {
        let emptyPodcastRule = SmartListRule(
            type: .podcast,
            comparison: .contains,
            value: .string("")
        )
        if case .success = SmartListRuleValidator.validateAll([emptyPodcastRule]) {
            XCTFail("Empty-string podcast rule should fail validation — evaluator silently skips it")
        }
    }

    /// Verify that mixing valid and invalid rules causes validateAll to fail.
    func testMixedValidAndInvalidRulesFailsValidation() {
        let validRule = SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
        let invalidRule = SmartListRule(type: .title, comparison: .contains, value: .string("   "))

        if case .success = SmartListRuleValidator.validateAll([validRule, invalidRule]) {
            XCTFail("Rule set containing an invalid rule should fail validateAll")
        }
    }

    // MARK: - Rule Order is Commutative

    func testRuleOrderIsCommutativeForEvaluation() {
        let episodes = makeSampleEpisodes()
        let vm = makeViewModel(allEpisodes: episodes)

        let rule1 = SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
        let rule2 = SmartListRule(type: .downloadStatus, comparison: .equals, value: .downloadStatus(.downloaded))

        let rulesAB = SmartListRuleSet(rules: [rule1, rule2], logic: .and)
        let rulesBA = SmartListRuleSet(rules: [rule2, rule1], logic: .and)

        let previewAB = vm.previewEpisodes(for: rulesAB)
        let previewBA = vm.previewEpisodes(for: rulesBA)

        XCTAssertEqual(Set(previewAB.map(\.id)), Set(previewBA.map(\.id)),
                       "Rule order should not affect AND/OR evaluation results")
    }

    // MARK: - Full Property Roundtrip

    func testEditRoundtripPreservesAllProperties() {
        let vm = makeViewModel()
        vm.createSmartPlaylist(
            name: "Round Trip",
            description: "Test roundtrip",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(3600)),
            ]),
            sortBy: .duration,
            maxEpisodes: 10,
            autoUpdate: false,
            refreshInterval: 900
        )

        let original = vm.customPlaylists[0]
        let newRules = SmartListRuleSet(rules: [
            SmartListRule(type: .rating, comparison: .greaterThan, value: .integer(3)),
        ])
        vm.updateSmartPlaylist(
            original
                .withName("Updated Name")
                .withDescription("Updated desc")
                .withRules(newRules)
                .withSortBy(.pubDateOldest)
                .withMaxEpisodes(20)
                .withAutoUpdate(true)
                .withRefreshInterval(600)
        )

        let saved = vm.customPlaylists[0]
        XCTAssertEqual(saved.name, "Updated Name")
        XCTAssertEqual(saved.description, "Updated desc")
        XCTAssertEqual(saved.rules.rules[0].type, .rating)
        XCTAssertEqual(saved.sortBy, .pubDateOldest)
        XCTAssertEqual(saved.maxEpisodes, 20)
        XCTAssertTrue(saved.autoUpdate)
        XCTAssertEqual(saved.refreshInterval, 600)
    }
}
