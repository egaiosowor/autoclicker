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

    /// Default shortcut for Profile 1: Option + Command + S
    static let defaultProfile1Combo = KeyCombo(
        keyCode: UInt16(kVK_ANSI_S),
        modifiers: [.option, .command]
    )

    /// Default shortcut for Profile 2: Option + Command + D
    static let defaultProfile2Combo = KeyCombo(
        keyCode: UInt16(kVK_ANSI_D),
        modifiers: [.option, .command]
    )

    /// Backward-compatibility alias
    static let defaultStartStopCombo = defaultProfile1Combo

    /// Function key preset: F6
    static let defaultF6StartStopCombo = KeyCombo(keyCode: UInt16(kVK_F6))

    // MARK: UI

    static let windowWidth: CGFloat = 430
    static let windowHeight: CGFloat = 600

    // MARK: Permission Polling

    static let permissionPollInterval: TimeInterval = 2.0
}

// MARK: - Interval Unit

enum IntervalUnit: String, CaseIterable, Identifiable, Codable {
    case milliseconds = "ms"
    case minutes = "min"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .milliseconds: return "Milliseconds"
        case .minutes: return "Minutes"
        }
    }

    func toSeconds(_ value: Double) -> TimeInterval {
        switch self {
        case .milliseconds:
            return value / 1000.0
        case .minutes:
            return value * 60.0
        }
    }
}
