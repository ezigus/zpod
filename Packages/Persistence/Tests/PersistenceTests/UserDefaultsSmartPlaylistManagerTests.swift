//
//  UserDefaultsSmartPlaylistManagerTests.swift
//  PersistenceTests
//
//  Tests for UserDefaultsSmartPlaylistManager:
//  persistence roundtrip, built-in handling, deletion guards, and CRUD isolation.
//

import XCTest
import CoreModels
@testable import Persistence

final class UserDefaultsSmartPlaylistManagerTests: XCTestCase {

    private var harness: UserDefaultsTestHarness!
    private var manager: UserDefaultsSmartPlaylistManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        harness = makeUserDefaultsHarness(prefix: "smart-playlist-manager")
        manager = UserDefaultsSmartPlaylistManager(userDefaults: harness.userDefaults)
    }

    override func tearDownWithError() throws {
        manager = nil
        harness = nil
        try super.tearDownWithError()
    }

    // MARK: - Built-in Handling

    func testBuiltInPlaylistsAlwaysPresentOnFreshStore() {
        let builtIns = manager.builtInSmartPlaylists()
        XCTAssertFalse(builtIns.isEmpty)
        XCTAssertTrue(builtIns.allSatisfy(\.isSystemGenerated))
    }

    func testBuiltInPlaylistsNotWrittenToUserDefaults() {
        // Built-ins are code-defined; nothing should be serialised on init
        let data = harness.userDefaults.data(forKey: "smart_episode_lists_v2")
        XCTAssertNil(data)
    }

    func testAllSmartPlaylistsReturnsSystemGeneratedFirst() {
        let custom = makeCustomPlaylist(name: "Aardvark")
        manager.createSmartPlaylist(custom)

        let all = manager.allSmartPlaylists()
        let lastSystemIdx = all.lastIndex { $0.isSystemGenerated }
        let firstCustomIdx = all.firstIndex { !$0.isSystemGenerated }
        if let lastS = lastSystemIdx, let firstC = firstCustomIdx {
            XCTAssertLessThan(lastS, firstC)
        } else {
            XCTFail("Expected both system and custom playlists")
        }
    }

    // MARK: - Persistence Roundtrip

    func testCustomPlaylistSurvivesReloadFromStorage() {
        let playlist = makeCustomPlaylist(name: "Night Drive")
        manager.createSmartPlaylist(playlist)

        let manager2 = UserDefaultsSmartPlaylistManager(userDefaults: harness.userDefaults)
        let found = manager2.findSmartPlaylist(id: playlist.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Night Drive")
    }

    func testReloadFromStoragePicksUpExternalChanges() {
        let manager2 = UserDefaultsSmartPlaylistManager(userDefaults: harness.userDefaults)
        let playlist = makeCustomPlaylist(name: "Morning Run")
        manager2.createSmartPlaylist(playlist)

        manager.reloadFromStorage()

        let found = manager.findSmartPlaylist(id: playlist.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Morning Run")
    }

    // MARK: - Create

    func testCreateCustomPlaylist() {
        let playlist = makeCustomPlaylist(name: "Commute")
        manager.createSmartPlaylist(playlist)

        XCTAssertTrue(manager.customSmartPlaylists().contains { $0.id == playlist.id })
        XCTAssertTrue(manager.allSmartPlaylists().contains { $0.id == playlist.id })
    }

    func testCreateDuplicateIdIsIdempotent() {
        let id = UUID().uuidString
        manager.createSmartPlaylist(makeCustomPlaylist(id: id, name: "First"))
        manager.createSmartPlaylist(makeCustomPlaylist(id: id, name: "Duplicate"))

        let customs = manager.customSmartPlaylists().filter { $0.id == id }
        XCTAssertEqual(customs.count, 1)
        XCTAssertEqual(customs.first?.name, "First")
    }

    func testCreateSystemGeneratedPlaylistIsRejected() {
        let systemPlaylist = SmartEpisodeListV2(
            id: "fake-system",
            name: "Fake Built-in",
            rules: makeRuleSet(),
            isSystemGenerated: true
        )
        manager.createSmartPlaylist(systemPlaylist)
        XCTAssertFalse(manager.customSmartPlaylists().contains { $0.id == "fake-system" })
    }

    // MARK: - Update

    func testUpdateChangesNameAndPersists() {
        let playlist = makeCustomPlaylist(name: "Old Name")
        manager.createSmartPlaylist(playlist)
        manager.updateSmartPlaylist(playlist.withName("New Name"))

        XCTAssertEqual(manager.findSmartPlaylist(id: playlist.id)?.name, "New Name")

        let manager2 = UserDefaultsSmartPlaylistManager(userDefaults: harness.userDefaults)
        XCTAssertEqual(manager2.findSmartPlaylist(id: playlist.id)?.name, "New Name")
    }

    func testUpdateNonExistentPlaylistIsNoop() {
        manager.updateSmartPlaylist(makeCustomPlaylist(id: "ghost-id", name: "Ghost"))
        XCTAssertTrue(manager.customSmartPlaylists().isEmpty)
    }

    func testUpdateSystemGeneratedPlaylistIsRejected() {
        guard let builtIn = manager.builtInSmartPlaylists().first else {
            return XCTFail("Expected at least one built-in playlist")
        }
        manager.updateSmartPlaylist(builtIn.withName("Hacked Name"))
        XCTAssertEqual(manager.findSmartPlaylist(id: builtIn.id)?.name, builtIn.name)
    }

    // MARK: - Delete

    func testDeleteCustomPlaylistRemovesIt() {
        let playlist = makeCustomPlaylist(name: "Temp List")
        manager.createSmartPlaylist(playlist)
        manager.deleteSmartPlaylist(id: playlist.id)

        XCTAssertNil(manager.findSmartPlaylist(id: playlist.id).flatMap { $0.isSystemGenerated ? nil : $0 })
        XCTAssertFalse(manager.customSmartPlaylists().contains { $0.id == playlist.id })
    }

    func testDeleteSystemGeneratedPlaylistIsRejected() {
        guard let builtIn = manager.builtInSmartPlaylists().first else {
            return XCTFail("Expected at least one built-in playlist")
        }
        manager.deleteSmartPlaylist(id: builtIn.id)
        XCTAssertNotNil(manager.findSmartPlaylist(id: builtIn.id))
    }

    func testDeleteNonExistentIdIsNoop() {
        manager.createSmartPlaylist(makeCustomPlaylist(name: "Alpha"))
        manager.createSmartPlaylist(makeCustomPlaylist(name: "Beta"))
        manager.deleteSmartPlaylist(id: "does-not-exist")
        XCTAssertEqual(manager.customSmartPlaylists().count, 2)
    }

    func testDeletedPlaylistDoesNotReturnAfterReload() {
        let playlist = makeCustomPlaylist(name: "Gone")
        manager.createSmartPlaylist(playlist)
        manager.deleteSmartPlaylist(id: playlist.id)

        let manager2 = UserDefaultsSmartPlaylistManager(userDefaults: harness.userDefaults)
        XCTAssertFalse(manager2.customSmartPlaylists().contains { $0.id == playlist.id })
    }

    // MARK: - Find

    func testFindSmartPlaylistByBuiltInId() {
        guard let builtIn = manager.builtInSmartPlaylists().first else {
            return XCTFail("Expected at least one built-in playlist")
        }
        let found = manager.findSmartPlaylist(id: builtIn.id)
        XCTAssertEqual(found?.id, builtIn.id)
    }

    func testFindSmartPlaylistByCustomId() {
        let playlist = makeCustomPlaylist(name: "Find Me")
        manager.createSmartPlaylist(playlist)
        XCTAssertEqual(manager.findSmartPlaylist(id: playlist.id)?.name, "Find Me")
    }

    func testFindSmartPlaylistReturnsNilForUnknownId() {
        XCTAssertNil(manager.findSmartPlaylist(id: "nonexistent"))
    }

    // MARK: - Templates

    func testAvailableTemplatesReturnsBuiltInTemplates() {
        XCTAssertFalse(manager.availableTemplates().isEmpty)
    }

    // MARK: - Helpers

    private func makeRuleSet() -> SmartListRuleSet {
        SmartListRuleSet(rules: [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
        ])
    }

    private func makeCustomPlaylist(id: String = UUID().uuidString, name: String) -> SmartEpisodeListV2 {
        SmartEpisodeListV2(id: id, name: name, rules: makeRuleSet())
    }
}
