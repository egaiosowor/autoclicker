import Carbon
import CoreGraphics
import Foundation

// MARK: - App Constants

enum Constants {

    // MARK: Safety Thresholds

    /// Hard minimum interval (seconds). Intervals below this are rejected (FR-01: 1 ms).
    static let minimumInterval: TimeInterval = 0.001  // 1 ms

    /// Threshold for rate cap stability warning (under 2 ms).
    static let rateCapWarningInterval: TimeInterval = 0.002  // 2 ms

    /// Pixel distance threshold for cursor-movement interrupt.
    static let cursorInterruptThreshold: CGFloat = 15.0

    // MARK: Default Interval

    static let defaultIntervalValue: Double = 100
    static let defaultIntervalUnit: IntervalUnit = .milliseconds

    // MARK: Default Hotkeys

    /// Default Start / Stop shortcut: Option + Command + S
    static let defaultStartStopCombo = KeyCombo(
        keyCode: UInt16(kVK_ANSI_S),
        modifiers: [.option, .command]
    )

    /// Default Pause / Resume shortcut: Option + Command + P
    static let defaultPauseResumeCombo = KeyCombo(
        keyCode: UInt16(kVK_ANSI_P),
        modifiers: [.option, .command]
    )

    /// Legacy F6 shortcuts
    static let defaultF6StartStopCombo = KeyCombo(keyCode: UInt16(kVK_F6))
    static let defaultF6PauseResumeCombo = KeyCombo(keyCode: UInt16(kVK_F6), modifiers: [.shift])

    // MARK: UI

    static let windowWidth: CGFloat = 430
    static let windowHeight: CGFloat = 600

    // MARK: Permission Polling

    static let permissionPollInterval: TimeInterval = 2.0
}

// MARK: - Interval Unit

enum IntervalUnit: String, CaseIterable, Identifiable {
    case milliseconds = "ms"
    case seconds = "s"
    case minutes = "min"
    case hours = "h"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .milliseconds: return "Milliseconds"
        case .seconds: return "Seconds"
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        }
    }

    /// Convert a value in this unit to seconds.
    func toSeconds(_ value: Double) -> TimeInterval {
        switch self {
        case .milliseconds: return value / 1_000.0
        case .seconds: return value
        case .minutes: return value * 60.0
        case .hours: return value * 3600.0
        }
    }
}
