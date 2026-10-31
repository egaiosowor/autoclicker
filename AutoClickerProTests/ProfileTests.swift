import Carbon
import XCTest
@testable import AutoClickerPro

final class ProfileLibraryTests: XCTestCase {

    func testDefaultLibraryHasOneProfile() {
        let library = ProfileLibrary(profiles: [])
        XCTAssertEqual(library.profiles.count, 1)
        XCTAssertEqual(library.profiles.first?.name, "Profile 1")
        XCTAssertEqual(library.selectedID, library.profiles.first?.id)
    }

    func testAddProfileGeneratesUniqueName() {
        var library = ProfileLibrary(profiles: [Profile(name: "Profile 1")])
        let p2 = library.add()
        XCTAssertEqual(p2.name, "Profile 2")
        XCTAssertEqual(library.profiles.count, 2)
        XCTAssertNil(p2.hotkey)
    }

    func testDuplicateProfileClonesSettingsWithoutHotkey() {
        var p1 = Profile(name: "Mining")
        p1.hotkey = KeyCombo(keyCode: UInt16(kVK_ANSI_1), modifiers: [.command])
        p1.targets = [TargetPoint(x: 100, y: 200, delayMs: 50)]
        p1.intervalValue = 42

        var library = ProfileLibrary(profiles: [p1], selectedID: p1.id)
        guard let copy = library.duplicate(id: p1.id) else {
            XCTFail("Duplicate failed")
            return
        }

        XCTAssertNotEqual(copy.id, p1.id)
        XCTAssertEqual(copy.name, "Mining copy")
        XCTAssertNil(copy.hotkey, "Hotkey should be nil to avoid collision")
        XCTAssertEqual(copy.intervalValue, 42)
        XCTAssertEqual(copy.targets.count, 1)
        XCTAssertNotEqual(copy.targets[0].id, p1.targets[0].id, "Target IDs must be refreshed")
        XCTAssertEqual(copy.targets[0].x, 100)
    }

    func testDeleteProfilePreventsDeletingLastProfile() {
        let p1 = Profile(name: "Only One")
        var library = ProfileLibrary(profiles: [p1])
        let resultID = library.delete(id: p1.id)
        XCTAssertEqual(resultID, p1.id)
        XCTAssertEqual(library.profiles.count, 1)
    }

    func testDeleteProfileSwitchesSelection() {
        let p1 = Profile(name: "P1")
        let p2 = Profile(name: "P2")
        let p3 = Profile(name: "P3")
        var library = ProfileLibrary(profiles: [p1, p2, p3], selectedID: p2.id)

        let nextSelectedID = library.delete(id: p2.id)
        XCTAssertEqual(library.profiles.count, 2)
        XCTAssertEqual(nextSelectedID, p3.id)
        XCTAssertEqual(library.selectedID, p3.id)
    }

    func testHotkeyConflictDetection() {
        let comboA = KeyCombo(keyCode: UInt16(kVK_ANSI_A), modifiers: [.command])
        let comboB = KeyCombo(keyCode: UInt16(kVK_ANSI_B), modifiers: [.command])

        var p1 = Profile(name: "P1")
        p1.hotkey = comboA
        var p2 = Profile(name: "P2")
        p2.hotkey = comboB

        let library = ProfileLibrary(profiles: [p1, p2])

        // Same profile should not conflict with itself
        XCTAssertNil(library.hotkeyConflict(comboA, excluding: p1.id))

        // Different profile using comboA should conflict
        let conflict = library.hotkeyConflict(comboA, excluding: p2.id)
        XCTAssertNotNil(conflict)
        XCTAssertEqual(conflict?.id, p1.id)

        // Unused combo should not conflict
        let comboC = KeyCombo(keyCode: UInt16(kVK_ANSI_C), modifiers: [.command])
        XCTAssertNil(library.hotkeyConflict(comboC, excluding: p2.id))
    }

    func testMergeProfilesDropsCollidingHotkeys() {
        let combo1 = KeyCombo(keyCode: UInt16(kVK_ANSI_1), modifiers: [.command])
        var existing = Profile(name: "Existing")
        existing.hotkey = combo1

        var library = ProfileLibrary(profiles: [existing])

        var imported1 = Profile(name: "Imported 1")
        imported1.hotkey = combo1 // Collides with existing!

        var imported2 = Profile(name: "Imported 2")
        let combo2 = KeyCombo(keyCode: UInt16(kVK_ANSI_2), modifiers: [.command])
        imported2.hotkey = combo2 // Unique!

        let addedIDs = library.merge(imported: [imported1, imported2])
        XCTAssertEqual(addedIDs.count, 2)
        XCTAssertEqual(library.profiles.count, 3)

        let merged1 = library.profiles.first { $0.id == addedIDs[0] }
        let merged2 = library.profiles.first { $0.id == addedIDs[1] }

        XCTAssertNil(merged1?.hotkey, "Colliding hotkey must be stripped")
        XCTAssertEqual(merged2?.hotkey, combo2, "Non-colliding hotkey should be retained")
    }
}

final class ProfileStoreTests: XCTestCase {

    func testExportAndImportRoundTrip() throws {
        var p1 = Profile(name: "Profile Alpha")
        p1.hotkey = KeyCombo(keyCode: UInt16(kVK_ANSI_A), modifiers: [.option, .command])
        p1.intervalValue = 123
        p1.targets = [TargetPoint(x: 10, y: 20, delayMs: 5)]

        let data = try ProfileStore.exportData([p1])
        let imported = try ProfileStore.importProfiles(from: data)

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported[0].name, "Profile Alpha")
        XCTAssertEqual(imported[0].hotkey, p1.hotkey)
        XCTAssertEqual(imported[0].intervalValue, 123)
        XCTAssertEqual(imported[0].targets.count, 1)
        XCTAssertEqual(imported[0].targets[0].x, 10)
    }

    func testLegacyMigration() {
        let suite = "TestDefaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let legacyCombo = KeyCombo(keyCode: UInt16(kVK_F6))
        let legacyData = try! JSONEncoder().encode(legacyCombo)
        defaults.set(legacyData, forKey: ProfileStore.legacyStartStopKey)

        let loaded = ProfileStore.load(from: defaults)
        XCTAssertEqual(loaded.profiles.count, 1)
        XCTAssertEqual(loaded.profiles[0].hotkey, legacyCombo)
    }
}

final class AppStateProfileIntegrationTests: XCTestCase {

    func testAppStateProfileSwitchingAndExecution() {
        var p1 = Profile(name: "P1")
        p1.intervalValue = 10
        p1.targets = [TargetPoint(x: 100, y: 100, delayMs: 0)]

        var p2 = Profile(name: "P2")
        p2.intervalValue = 20
        p2.targets = [TargetPoint(x: 200, y: 200, delayMs: 0)]

        let library = ProfileLibrary(profiles: [p1, p2], selectedID: p1.id)
        let appState = AppState(library: library)

        XCTAssertEqual(appState.selectedProfile.id, p1.id)
        XCTAssertEqual(appState.selectedProfile.name, "P1")

        // Switch selection to P2
        appState.selectProfile(id: p2.id)
        XCTAssertEqual(appState.selectedProfile.id, p2.id)
        XCTAssertEqual(appState.selectedProfile.name, "P2")

        // Modify a property via binding
        appState.intervalValueBinding.wrappedValue = 99
        XCTAssertEqual(appState.selectedProfile.intervalValue, 99)

        // Add a profile
        let p3 = appState.addProfile()
        XCTAssertEqual(appState.library.profiles.count, 3)
        XCTAssertEqual(appState.selectedProfile.id, p3.id)

        // Delete P3
        appState.deleteProfile(id: p3.id)
        XCTAssertEqual(appState.library.profiles.count, 2)
    }
}
