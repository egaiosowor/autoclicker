import Foundation

// MARK: - Click Configuration

/// The complete set of parameters that define a clicking session.
struct ClickConfiguration {

    // MARK: Timing

    /// The raw interval value entered by the user (e.g., 100).
    var intervalValue: Double = Constants.defaultIntervalValue

    /// The unit of the interval (ms, s, m, h).
    var intervalUnit: IntervalUnit = Constants.defaultIntervalUnit

    /// The computed interval in seconds, ready for the timer.
    var intervalInSeconds: TimeInterval {
        intervalUnit.toSeconds(intervalValue)
    }

    // MARK: Click Type

    /// Which mouse button to click.
    var button: ClickButton = .left

    /// Single, double, or triple click.
    var action: ClickAction = .single

    // MARK: Targeting

    /// Ordered list of fixed targets to click with individual wait delays.
    var targets: [TargetPoint] = [TargetPoint(x: 500, y: 500, delayMs: 0)]

    // MARK: Execution

    /// When to stop — infinite or after N clicks.
    var executionLimit: ExecutionLimit = .infinite

    // MARK: Safety

    /// Whether to halt if the user moves the mouse during automation.
    var cursorInterruptEnabled: Bool = false
}
