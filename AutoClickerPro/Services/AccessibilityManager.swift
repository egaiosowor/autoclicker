import AppKit
import ApplicationServices
import Combine
import Foundation

// MARK: - Accessibility Manager

/// Monitors macOS Accessibility permission state and provides onboarding helpers.
final class AccessibilityManager: ObservableObject {

    @Published private(set) var isGranted: Bool = false

    private var pollTimer: Timer?

    init() {
        // Check immediately on launch.
        isGranted = AXIsProcessTrusted()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Permission Actions

    /// Triggers the system trust prompt if not already trusted.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings → Privacy & Security → Accessibility.
    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Polling

    /// Polls `AXIsProcessTrusted()` every few seconds so the UI stays in sync
    /// when the user toggles the permission outside the app.
    private func startPolling() {
        let timer = Timer(timeInterval: Constants.permissionPollInterval, repeats: true) { [weak self] _ in
            let trusted = AXIsProcessTrusted()
            if self?.isGranted != trusted {
                DispatchQueue.main.async {
                    self?.isGranted = trusted
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
}
