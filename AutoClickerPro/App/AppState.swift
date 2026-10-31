import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - App State

/// Central observable object wiring services together and holding the user's profile library.
final class AppState: ObservableObject {

    // MARK: Library State

    @Published var library: ProfileLibrary
    @Published var runningProfileID: UUID?

    // MARK: Services

    let engine = ClickEngine()
    let accessibility = AccessibilityManager()
    let hotkeys = HotkeyManager()

    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    init(library: ProfileLibrary = ProfileStore.load()) {
        self.library = library

        // Sync initial hotkeys to manager
        syncHotkeys()

        // Wire hotkey callbacks to engine actions.
        hotkeys.onHotkey = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .triggerProfile(let id):
                self.triggerProfile(id: id)
            case .stopOnly:
                self.stopEngine()
            }
        }

        // Forward engine changes to AppState so any view observing AppState updates immediately
        engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // When engine finishes or stops, clear runningProfileID
        engine.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                guard let self = self else { return }
                if !running {
                    self.runningProfileID = nil
                }
            }
            .store(in: &cancellables)

        // React dynamically to permission changes.
        accessibility.$isGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.hotkeys.startListening()  // idempotent
                    if self.engine.engineError == .permissionDenied {
                        self.engine.engineError = nil
                    }
                } else {
                    // Gracefully stop engine and hotkeys if permission is revoked mid-session.
                    if self.engine.isRunning {
                        self.stopEngine()
                        self.engine.engineError = .permissionDenied
                    }
                    self.hotkeys.stopListening()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Selected Profile Accessors

    var selectedProfile: Profile {
        library.selected ?? library.profiles[0]
    }

    var runningProfile: Profile? {
        guard let id = runningProfileID else { return nil }
        return library.profiles.first { $0.id == id }
    }

    func binding<T>(for keyPath: WritableKeyPath<Profile, T>) -> Binding<T> {
        Binding(
            get: { [weak self] in
                guard let self = self, let profile = self.library.selected else {
                    return Profile()[keyPath: keyPath]
                }
                return profile[keyPath: keyPath]
            },
            set: { [weak self] newValue in
                guard let self = self,
                      let idx = self.library.profiles.firstIndex(where: { $0.id == self.library.selectedID })
                else { return }
                self.library.profiles[idx][keyPath: keyPath] = newValue
                self.syncHotkeys()
                self.saveLibrary()
                self.objectWillChange.send()
            }
        )
    }

    var intervalValueBinding: Binding<Double> { binding(for: \.intervalValue) }
    var intervalUnitBinding: Binding<IntervalUnit> { binding(for: \.intervalUnit) }
    var clickButtonBinding: Binding<ClickButton> { binding(for: \.button) }
    var clickActionBinding: Binding<ClickAction> { binding(for: \.action) }
    var targetsBinding: Binding<[TargetPoint]> { binding(for: \.targets) }
    var executionLimitIsFiniteBinding: Binding<Bool> { binding(for: \.executionLimitIsFinite) }
    var executionLimitCountBinding: Binding<Int> { binding(for: \.executionLimitCount) }
    var cursorInterruptEnabledBinding: Binding<Bool> { binding(for: \.cursorInterruptEnabled) }
    var selectedHotkeyBinding: Binding<KeyCombo?> { binding(for: \.hotkey) }

    // MARK: - Profile Management

    func selectProfile(id: UUID) {
        guard library.profiles.contains(where: { $0.id == id }) else { return }
        library.selectedID = id
        saveLibrary()
        objectWillChange.send()
    }

    @discardableResult
    func addProfile() -> Profile {
        let profile = library.add()
        library.selectedID = profile.id
        syncHotkeys()
        saveLibrary()
        objectWillChange.send()
        return profile
    }

    @discardableResult
    func duplicateProfile(id: UUID) -> Profile? {
        guard let copy = library.duplicate(id: id) else { return nil }
        library.selectedID = copy.id
        syncHotkeys()
        saveLibrary()
        objectWillChange.send()
        return copy
    }

    func deleteProfile(id: UUID) {
        if runningProfileID == id {
            stopEngine()
        }
        library.delete(id: id)
        syncHotkeys()
        saveLibrary()
        objectWillChange.send()
    }

    func renameProfile(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = library.profiles.firstIndex(where: { $0.id == id }) {
            library.profiles[idx].name = trimmed
            saveLibrary()
            objectWillChange.send()
        }
    }

    func syncHotkeys() {
        var map: [UUID: KeyCombo] = [:]
        for profile in library.profiles {
            if let combo = profile.hotkey {
                map[profile.id] = combo
            }
        }
        hotkeys.setHotkeys(map)
    }

    func saveLibrary() {
        ProfileStore.save(library)
    }

    // MARK: - Execution

    func triggerProfile(id: UUID) {
        // Resign first responder so any active text field commits its value immediately
        NSApp.keyWindow?.makeFirstResponder(nil)

        if engine.isRunning {
            if runningProfileID == id {
                // Toggling off the active profile
                stopEngine()
                return
            }
            // Switching profiles: stop current sequence
            engine.stop()
        }

        guard accessibility.isGranted else {
            engine.engineError = .permissionDenied
            return
        }

        guard let profile = library.profiles.first(where: { $0.id == id }) else { return }
        library.selectedID = id
        runningProfileID = id
        engine.start(config: profile.configuration)
    }

    func toggleEngine() {
        triggerProfile(id: library.selectedID)
    }

    func stopEngine() {
        runningProfileID = nil
        engine.stop()
    }

    // MARK: - Import / Export

    func exportProfilesData() throws -> Data {
        return try ProfileStore.exportData(library.profiles)
    }

    @discardableResult
    func importProfiles(from data: Data) throws -> [UUID] {
        let imported = try ProfileStore.importProfiles(from: data)
        let addedIDs = library.merge(imported: imported)
        if let firstAdded = addedIDs.first {
            library.selectedID = firstAdded
        }
        syncHotkeys()
        saveLibrary()
        objectWillChange.send()
        return addedIDs
    }

    func exportProfiles() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "AutoClickerProfiles.json"
        panel.prompt = "Export"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try exportProfilesData()
                try data.write(to: url)
            } catch {
                print("[AppState] Export error: \(error)")
            }
        }
    }

    func importProfiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Import"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                _ = try importProfiles(from: data)
            } catch {
                print("[AppState] Import error: \(error)")
            }
        }
    }
}
