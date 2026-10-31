import Foundation

// MARK: - Profile

/// A named, saveable click sequence with its own optional global hotkey.
struct Profile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "Profile"
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

/// Pure, in-memory collection logic (no UI, no persistence) so it can be unit tested.
struct ProfileLibrary: Equatable {
    var profiles: [Profile]
    var selectedID: UUID

    init(profiles: [Profile], selectedID: UUID? = nil) {
        let list = profiles.isEmpty ? [Profile(name: "Profile 1")] : profiles
        self.profiles = list
        self.selectedID = list.contains(where: { $0.id == selectedID }) ? selectedID! : list[0].id
    }

    var selected: Profile? { profiles.first { $0.id == selectedID } }

    /// First other profile already using `combo`, if any.
    func hotkeyConflict(_ combo: KeyCombo, excluding id: UUID) -> Profile? {
        profiles.first { $0.id != id && $0.hotkey == combo }
    }

    /// Adds a fresh profile (no hotkey) and returns it.
    @discardableResult
    mutating func add() -> Profile {
        let profile = Profile(name: uniqueName(base: "Profile \(profiles.count + 1)"))
        profiles.append(profile)
        return profile
    }

    /// Copies a profile (without its hotkey, to avoid a conflict) right after the original.
    @discardableResult
    mutating func duplicate(id: UUID) -> Profile? {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = profiles[index]
        copy.id = UUID()
        copy.name = uniqueName(base: "\(copy.name) copy")
        copy.hotkey = nil
        copy.targets = copy.targets.map { var t = $0; t.id = UUID(); return t }
        profiles.insert(copy, at: index + 1)
        return copy
    }

    /// Deletes a profile. The last remaining profile cannot be deleted.
    /// Returns the profile that should be selected afterwards.
    @discardableResult
    mutating func delete(id: UUID) -> UUID {
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else {
            return selectedID
        }
        profiles.remove(at: index)
        if selectedID == id {
            selectedID = profiles[min(index, profiles.count - 1)].id
        }
        return selectedID
    }

    /// Appends imported profiles with fresh ids. A hotkey that collides with an existing
    /// one is dropped. Returns the ids of the profiles that were added.
    @discardableResult
    mutating func merge(imported: [Profile]) -> [UUID] {
        var added: [UUID] = []
        for var profile in imported {
            profile.id = UUID()
            profile.targets = profile.targets.map { var t = $0; t.id = UUID(); return t }
            if let combo = profile.hotkey, hotkeyConflict(combo, excluding: profile.id) != nil {
                profile.hotkey = nil
            }
            profile.name = uniqueName(base: profile.name.isEmpty ? "Imported" : profile.name)
            profiles.append(profile)
            added.append(profile.id)
        }
        return added
    }

    private func uniqueName(base: String) -> String {
        let existing = Set(profiles.map(\.name))
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }
}

// MARK: - Persistence

/// Stores the profile library in `UserDefaults`.
enum ProfileStore {
    static let profilesKey = "AutoClicker.Profiles"
    static let selectedKey = "AutoClicker.SelectedProfile"
    /// Pre-profiles single hotkey, migrated onto the first profile.
    static let legacyStartStopKey = "AutoClicker.Hotkey.StartStop"

    static func load(from defaults: UserDefaults = .standard) -> ProfileLibrary {
        if let data = defaults.data(forKey: profilesKey),
           let profiles = try? JSONDecoder().decode([Profile].self, from: data),
           !profiles.isEmpty {
            let selected = defaults.string(forKey: selectedKey).flatMap(UUID.init(uuidString:))
            return ProfileLibrary(profiles: profiles, selectedID: selected)
        }

        // First launch with profiles: carry over the old shortcut (or use the default).
        var first = Profile(name: "Profile 1")
        if let data = defaults.data(forKey: legacyStartStopKey),
           let legacy = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            first.hotkey = legacy
        } else {
            first.hotkey = Constants.defaultStartStopCombo
        }
        return ProfileLibrary(profiles: [first])
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

    /// Accepts either an array of profiles or a single profile object.
    static func importProfiles(from data: Data) throws -> [Profile] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([Profile].self, from: data) { return list }
        return [try decoder.decode(Profile.self, from: data)]
    }
}

