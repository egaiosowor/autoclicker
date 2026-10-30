import Combine
import SwiftUI

// MARK: - App State

/// Central observable object wiring services together and holding the user's configuration.
final class AppState: ObservableObject {

    // MARK: Configuration (bound to UI)

    @Published var intervalValue: Double = Constants.defaultIntervalValue
    @Published var intervalUnit: IntervalUnit = Constants.defaultIntervalUnit
    @Published var clickButton: ClickButton = .left
    @Published var clickAction: ClickAction = .single
    @Published var targets: [TargetPoint] = [
        TargetPoint(x: 500, y: 500, delayMs: 0)
    ]
    @Published var executionLimitIsFinite: Bool = false
    @Published var executionLimitCount: Int = 100
    @Published var cursorInterruptEnabled: Bool = false

    // MARK: Services

    let engine = ClickEngine()
    let accessibility = AccessibilityManager()
    let hotkeys = HotkeyManager()

    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    init() {
        // Wire hotkey callbacks to engine actions.
        hotkeys.onHotkey = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .toggleStartStop:
                self.toggleEngine()
            case .stopOnly:
                self.stopEngine()
            }
        }

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
                        self.engine.stop()
                        self.engine.engineError = .permissionDenied
                    }
                    self.hotkeys.stopListening()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Config

    /// Builds the current `ClickConfiguration` from published UI state.
    var currentConfiguration: ClickConfiguration {
        var config = ClickConfiguration()
        config.intervalValue = intervalValue
        config.intervalUnit = intervalUnit
        config.button = clickButton
        config.action = clickAction
        config.targets = targets.isEmpty ? [TargetPoint(x: 500, y: 500, delayMs: 0)] : targets
        config.executionLimit = executionLimitIsFinite
            ? .count(executionLimitCount)
            : .infinite
        config.cursorInterruptEnabled = cursorInterruptEnabled
        return config
    }

    // MARK: - Actions

    func toggleEngine() {
        // Resign first responder so any active text field commits its value immediately
        NSApp.keyWindow?.makeFirstResponder(nil)

        if engine.isRunning {
            engine.stop()
        } else {
            guard accessibility.isGranted else {
                engine.engineError = .permissionDenied
                return
            }
            engine.start(config: currentConfiguration)
        }
    }

    func stopEngine() {
        engine.stop()
    }
}
