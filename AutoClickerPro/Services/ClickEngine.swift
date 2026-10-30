import Combine
import CoreGraphics
import Foundation

// MARK: - Click Engine

/// The heart of the app. Fires synthetic mouse events on a precision timer.
final class ClickEngine: ObservableObject {

    // MARK: Published State

    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var clickCount: Int = 0
    @Published private(set) var startDate: Date?

    /// Non-nil when the engine refused to start or stopped due to a safety check.
    @Published var engineError: EngineError?

    // MARK: Private (owned exclusively by `queue`)

    private let queue = DispatchQueue(label: "com.autoclickerpro.engine", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var config: ClickConfiguration?
    private var running = false
    private var paused = false
    private var lastCursorPosition: CGPoint?
    private var localClickCount: Int = 0
    private var lastUIUpdateTime: CFAbsoluteTime = 0
    private var currentTargetIndex: Int = 0
    private var activity: NSObjectProtocol?

    // MARK: - Lifecycle

    /// Validates the configuration, then begins posting click events.
    func start(config: ClickConfiguration) {
        guard !isRunning else { return }

        guard !config.targets.isEmpty else {
            engineError = .noTargets
            return
        }

        // The global interval plus each target's extra wait forms the delay after that click.
        guard config.intervalInSeconds >= Constants.minimumInterval else {
            engineError = .intervalTooFast(config.intervalInSeconds)
            return
        }

        engineError = nil
        clickCount = 0
        startDate = Date()
        isRunning = true
        isPaused = false

        queue.async { [weak self] in
            guard let self = self else { return }
            self.config = config
            self.running = true
            self.paused = false
            self.localClickCount = 0
            self.lastUIUpdateTime = 0
            self.lastCursorPosition = nil
            self.currentTargetIndex = 0
            self.activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "AutoClicker running"
            )

            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: self.queue)
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
            // Click immediately on start; delays apply between clicks.
            self.schedule(after: 0)
        }
    }

    /// Pauses the click loop. Safe to call when already paused.
    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        queue.async { [weak self] in
            self?.paused = true
        }
    }

    /// Resumes a paused click loop.
    func resume() {
        guard isRunning, isPaused else { return }
        isPaused = false
        queue.async { [weak self] in
            guard let self = self, self.running, self.paused else { return }
            self.paused = false
            self.schedule(after: 0)
        }
    }

    /// Completely stops and tears down the engine.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        isPaused = false

        queue.async { [weak self] in
            guard let self = self else { return }
            let finalCount = self.localClickCount
            self.teardown()
            DispatchQueue.main.async {
                self.clickCount = finalCount
            }
        }
    }

    // MARK: - Queue-confined helpers

    private func teardown() {
        running = false
        paused = false
        timer?.cancel()
        timer = nil
        config = nil
        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    /// Re-arms the single timer; no new timer is allocated per click.
    private func schedule(after delay: TimeInterval) {
        guard running, !paused, let timer = timer else { return }
        let deadline: DispatchTime = delay <= 0 ? .now() : (.now() + delay)
        timer.schedule(deadline: deadline, leeway: .nanoseconds(0))
    }

    // MARK: - Tick

    private func tick() {
        guard running, !paused, let config = config, !config.targets.isEmpty else { return }

        // --- Cursor-movement interrupt ---
        if config.cursorInterruptEnabled {
            let current = CGEvent(source: nil)?.location ?? .zero
            if let last = lastCursorPosition {
                let dx = current.x - last.x
                let dy = current.y - last.y
                if sqrt(dx * dx + dy * dy) > Constants.cursorInterruptThreshold {
                    let finalCount = localClickCount
                    teardown()
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.clickCount = finalCount
                        self.isRunning = false
                        self.isPaused = false
                        self.engineError = .cursorInterrupt
                    }
                    return
                }
            }
            lastCursorPosition = current
        }

        // --- Click the current target ---
        let targetIndex = currentTargetIndex % config.targets.count
        let target = config.targets[targetIndex]
        postClick(at: CGPoint(x: target.x, y: target.y), button: config.button, action: config.action)

        localClickCount += 1
        let currentCount = localClickCount

        // --- Execution limit ---
        if case .count(let max) = config.executionLimit, currentCount >= max {
            teardown()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.clickCount = currentCount
                self.isRunning = false
                self.isPaused = false
            }
            return
        }

        currentTargetIndex = (targetIndex + 1) % config.targets.count

        // --- Throttled UI counter update (~30 FPS) ---
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastUIUpdateTime >= 0.033 {
            lastUIUpdateTime = now
            DispatchQueue.main.async { [weak self] in
                self?.clickCount = currentCount
            }
        }

        // --- Delay before the next click: global interval + this target's extra wait ---
        let delay = max(config.intervalInSeconds + max(target.delayMs, 0) / 1000.0, 0)
        schedule(after: delay)
    }

    // MARK: - Event Posting

    /// Creates and posts CGEvent mouse down/up pairs for the configured click type.
    private func postClick(at point: CGPoint, button: ClickButton, action: ClickAction) {
        let clickCount = action.rawValue  // 1, 2, or 3

        // For double/triple clicks we must send sequential down/up pairs
        // with incrementing clickState.
        for state in 1...clickCount {
            guard let down = CGEvent(
                mouseEventSource: nil,
                mouseType: button.mouseDownType,
                mouseCursorPosition: point,
                mouseButton: button.cgButton
            ) else { continue }

            guard let up = CGEvent(
                mouseEventSource: nil,
                mouseType: button.mouseUpType,
                mouseCursorPosition: point,
                mouseButton: button.cgButton
            ) else { continue }

            down.setIntegerValueField(.mouseEventClickState, value: Int64(state))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(state))

            if button == .middle {
                down.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
                up.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
            }

            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - Engine Error

enum EngineError: LocalizedError, Equatable {
    case intervalTooFast(TimeInterval)
    case cursorInterrupt
    case permissionDenied
    case noTargets

    var errorDescription: String? {
        switch self {
        case .intervalTooFast(let interval):
            let ms = interval * 1000
            return String(format: "Interval too fast (%.1f ms). Minimum is %.0f ms.", ms, Constants.minimumInterval * 1000)
        case .cursorInterrupt:
            return "Stopped: mouse was moved during automation."
        case .permissionDenied:
            return "Accessibility permission is required."
        case .noTargets:
            return "Please add at least one target coordinate."
        }
    }
}
