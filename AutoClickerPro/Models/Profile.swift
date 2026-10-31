import Foundation

// MARK: - Profile

/// A named, saveable click sequence with its own optional global hotkey.
struct Profile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "Profile 1"
    /// Global shortcut that starts / stops this profile. `nil` = button only.
    var hotkey: KeyCombo?

    var intervalValue: Double = Constants.defaultIntervalValue
    var intervalUnit: IntervalUnit = Constants.defaultIntervalUnit
    var button: ClickButton = .left
    var action: ClickAction = .single
    var targets: [TargetPoint] = [TargetPoint(x: 500, y: 500, delayMs: 0)]
    var executionLimitIsFinite: Bool = false
    var executionLimitCount: Int = 100
    var cursorInterruptEnabled: Bool = false

    /// The engine configuration for this profile.
    var configuration: ClickConfiguration {
        var config = ClickConfiguration()
        config.intervalValue = intervalValue
        config.intervalUnit = intervalUnit
        config.button = button
        config.action = action
        config.targets = targets.isEmpty ? [TargetPoint(x: 500, y: 500, delayMs: 0)] : targets
        config.executionLimit = executionLimitIsFinite ? .count(executionLimitCount) : .infinite
        config.cursorInterruptEnabled = cursorInterruptEnabled
        return config
    }
}

// MARK: - Profile Library

/// Pure collection logic for managing the app's two profiles.
struct ProfileLibrary: Equatable {
    var profiles: [Profile]
    var selectedID: UUID

    static func defaultTwoProfiles() -> [Profile] {
        var p1 = Profile(name: "Profile 1")
        p1.hotkey = Constants.defaultProfile1Combo

        var p2 = Profile(name: "Profile 2")
        p2.hotkey = Constants.defaultProfile2Combo

        return [p1, p2]
    }

    init(profiles: [Profile] = [], selectedID: UUID? = nil) {
        var list: [Profile]
        if profiles.count >= 2 {
            list = Array(profiles.prefix(2))
        } else if profiles.count == 1 {
            var p1 = profiles[0]
            if p1.hotkey == nil { p1.hotkey = Constants.defaultProfile1Combo }
            var p2 = Profile(name: "Profile 2")
            p2.hotkey = Constants.defaultProfile2Combo
            list = [p1, p2]
        } else {
            list = Self.defaultTwoProfiles()
        }

        if list[0].hotkey == nil { list[0].hotkey = Constants.defaultProfile1Combo }
        if list[1].hotkey == nil { list[1].hotkey = Constants.defaultProfile2Combo }

        self.profiles = list
        self.selectedID = list.contains(where: { $0.id == selectedID }) ? selectedID! : list[0].id
    }

    var selected: Profile? { profiles.first { $0.id == selectedID } }

    var selectedIndex: Int {
        profiles.firstIndex(where: { $0.id == selectedID }) ?? 0
    }

    /// First other profile already using `combo`, if any.
    func hotkeyConflict(_ combo: KeyCombo, excluding id: UUID) -> Profile? {
        profiles.first { $0.id != id && $0.hotkey == combo }
    }
}

// MARK: - Persistence

/// Stores the profiles in `UserDefaults`.
enum ProfileStore {
    static let profilesKey = "AutoClicker.Profiles"
    static let selectedKey = "AutoClicker.SelectedProfile"
    /// Pre-profiles single hotkey, migrated onto Profile 1.
    static let legacyStartStopKey = "AutoClicker.Hotkey.StartStop"

    static func load(from defaults: UserDefaults = .standard) -> ProfileLibrary {
        if let data = defaults.data(forKey: profilesKey),
           var profiles = try? JSONDecoder().decode([Profile].self, from: data),
           !profiles.isEmpty {
            let selected = defaults.string(forKey: selectedKey).flatMap(UUID.init(uuidString:))
            if profiles.count == 1 {
                if profiles[0].hotkey == nil {
                    profiles[0].hotkey = Constants.defaultProfile1Combo
                }
                var p2 = Profile(name: "Profile 2")
                p2.hotkey = Constants.defaultProfile2Combo
                profiles.append(p2)
            } else if profiles.count > 2 {
                profiles = Array(profiles.prefix(2))
            }
            if profiles[0].hotkey == nil { profiles[0].hotkey = Constants.defaultProfile1Combo }
            if profiles[1].hotkey == nil { profiles[1].hotkey = Constants.defaultProfile2Combo }
            return ProfileLibrary(profiles: profiles, selectedID: selected)
        }

        // First launch: initialize two profiles
        var p1 = Profile(name: "Profile 1")
        if let data = defaults.data(forKey: legacyStartStopKey),
           let legacy = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            p1.hotkey = legacy
        } else {
            p1.hotkey = Constants.defaultProfile1Combo
        }

        var p2 = Profile(name: "Profile 2")
        p2.hotkey = Constants.defaultProfile2Combo

        return ProfileLibrary(profiles: [p1, p2])
    }

    static func save(_ library: ProfileLibrary, to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(library.profiles) {
            defaults.set(data, forKey: profilesKey)
        }
        defaults.set(library.selectedID.uuidString, forKey: selectedKey)
    }

    // MARK: Import / export

    static func exportData(_ profiles: [Profile]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(profiles)
    }

    static func importProfiles(from data: Data) throws -> [Profile] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([Profile].self, from: data) { return list }
        return [try decoder.decode(Profile.self, from: data)]
    }
}
