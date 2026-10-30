import Foundation

// MARK: - Safety Guard

/// Static utilities for validating engine configuration against safety thresholds.
enum SafetyGuard {

    /// Returns `true` if the interval is safe (>= hard minimum).
    static func validateInterval(_ interval: TimeInterval) -> Bool {
        return interval >= Constants.minimumInterval
    }

    /// Returns a user-facing warning string if the interval is dangerously low
    /// but still above the hard minimum. Returns `nil` if all is fine.
    static func intervalWarning(_ interval: TimeInterval) -> String? {
        if interval < Constants.minimumInterval {
            return String(
                format: "Interval below %.0f ms minimum threshold — engine will refuse to start.",
                Constants.minimumInterval * 1000
            )
        }
        if interval < Constants.rateCapWarningInterval {
            return "Interval under 2 ms: may cause system instability or high CPU load."
        }
        if interval < 0.010 {
            return "Fast interval (<10 ms). This may cause elevated CPU usage."
        }
        return nil
    }
}
