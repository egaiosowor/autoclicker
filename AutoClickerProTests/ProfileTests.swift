import Carbon
import XCTest
@testable import AutoClickerPro

final class ProfileLibraryTests: XCTestCase {

    func testDefaultLibraryHasTwoProfiles() {
        let library = ProfileLibrary(profiles: [])
        XCTAssertEqual(library.profiles.count, 2)
        XCTAssertEqual(library.profiles[0].name, "Profile 1")
        XCTAssertEqual(library.profiles[1].name, "Profile 2")
        XCTAssertEqual(library.selectedID, library.profiles[0].id)
    }

    func testDefaultHotkeysAreSAndD() {
        let library = ProfileLibrary(profiles: [])
        XCTAssertEqual(library.profiles[0].hotkey, Constants.defaultProfile1Combo)
        XCTAssertEqual(library.profiles[1].hotkey, Constants.defaultProfile2Combo)
        XCTAssertEqual(library.profiles[0].hotkey?.displayString, "⌥⌘ S")
        XCTAssertEqual(library.profiles[1].hotkey?.displayString, "⌥⌘ D")
    }

    func testHotkeyConflictDetection() {
        let comboA = Constants.defaultProfile1Combo
        let comboB = Constants.defaultProfile2Combo

        let library = ProfileLibrary()

        // Same profile should not conflict with itself
        XCTAssertNil(library.hotkeyConflict(comboA, excluding: library.profiles[0].id))

        // Profile 2 trying to use comboA (used by Profile 1) should conflict
        let conflict = library.hotkeyConflict(comboA, excluding: library.profiles[1].id)
        XCTAssertNotNil(conflict)
        XCTAssertEqual(conflict?.id, library.profiles[0].id)

        // Profile 1 trying to use comboB (used by Profile 2) should conflict
        let conflict2 = library.hotkeyConflict(comboB, excluding: library.profiles[0].id)
        XCTAssertNotNil(conflict2)
        XCTAssertEqual(conflict2?.id, library.profiles[1].id)

        // Unused combo should not conflict
        let comboC = KeyCombo(keyCode: UInt16(kVK_ANSI_C), modifiers: [.command])
        XCTAssertNil(library.hotkeyConflict(comboC, excluding: library.profiles[0].id))
    }
}

final class ProfileStoreTests: XCTestCase {

    func testExportAndImportRoundTrip() throws {
        var p1 = Profile(name: "Profile 1")
        p1.hotkey = Constants.defaultProfile1Combo
        p1.intervalValue = 123
        p1.targets = [TargetPoint(x: 10, y: 20, delayMs: 5)]

        var p2 = Profile(name: "Profile 2")
        p2.hotkey = Constants.defaultProfile2Combo
        p2.intervalValue = 456

        let data = try ProfileStore.exportData([p1, p2])
        let imported = try ProfileStore.importProfiles(from: data)

        XCTAssertEqual(imported.count, 2)
        XCTAssertEqual(imported[0].hotkey, Constants.defaultProfile1Combo)
        XCTAssertEqual(imported[1].hotkey, Constants.defaultProfile2Combo)
        XCTAssertEqual(imported[0].intervalValue, 123)
        XCTAssertEqual(imported[1].intervalValue, 456)
    }

    func testLegacyMigration() {
        let suite = "TestDefaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let legacyCombo = KeyCombo(keyCode: UInt16(kVK_F6))
        let legacyData = try! JSONEncoder().encode(legacyCombo)
        defaults.set(legacyData, forKey: ProfileStore.legacyStartStopKey)

        let loaded = ProfileStore.load(from: defaults)
        XCTAssertEqual(loaded.profiles.count, 2)
        XCTAssertEqual(loaded.profiles[0].hotkey, legacyCombo)
        XCTAssertEqual(loaded.profiles[1].hotkey, Constants.defaultProfile2Combo)
    }
}

final class AppStateProfileIntegrationTests: XCTestCase {

    func testAppStateProfileSwitchingAndExecution() {
        var p1 = Profile(name: "Profile 1")
        p1.intervalValue = 10
        p1.hotkey = Constants.defaultProfile1Combo
        p1.targets = [TargetPoint(x: 100, y: 100, delayMs: 0)]

        var p2 = Profile(name: "Profile 2")
        p2.intervalValue = 20
        p2.hotkey = Constants.defaultProfile2Combo
        p2.targets = [TargetPoint(x: 200, y: 200, delayMs: 0)]

        let library = ProfileLibrary(profiles: [p1, p2], selectedID: p1.id)
        let appState = AppState(library: library)

        XCTAssertEqual(appState.selectedProfile.id, p1.id)
        XCTAssertEqual(appState.selectedProfile.name, "Profile 1")

        // Switch selection to Profile 2
        appState.selectProfile(id: p2.id)
        XCTAssertEqual(appState.selectedProfile.id, p2.id)
        XCTAssertEqual(appState.selectedProfile.name, "Profile 2")

        // Modify a property via binding
        appState.intervalValueBinding.wrappedValue = 99
        XCTAssertEqual(appState.selectedProfile.intervalValue, 99)

        // Hotkeys are mapped to both profiles
        XCTAssertEqual(appState.hotkeys.profileHotkeys[p1.id], Constants.defaultProfile1Combo)
        XCTAssertEqual(appState.hotkeys.profileHotkeys[p2.id], Constants.defaultProfile2Combo)
    }
}
