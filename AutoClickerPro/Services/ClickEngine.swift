import Combine
import CoreGraphics
import Foundation

// MARK: - Click Engine

/// The heart of the app. Fires synthetic mouse events on a precision timer.
final class ClickEngine: ObservableObject {

    // MARK: Published State

    @Published private(set) var isRunning = false
    @Published private(set) var clickCount: Int = 0
    @Published private(set) var startDate: Date?
    @Published private(set) var activeTargetIndex: Int = 0

    /// Non-nil when the engine refused to start or stopped due to a safety check.
    @Published var engineError: EngineError?

    // MARK: Private (owned exclusively by `queue`)

    private let queue = DispatchQueue(label: "com.autoclickerpro.engine", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var config: ClickConfiguration?
    private var running = false
    private var lastCursorPosition: CGPoint?
    private var localClickCount: Int = 0
    private var lastUIUpdateTime: CFAbsoluteTime = 0
    private var currentTargetIndex: Int = 0
    private var activity: NSObjectProtocol?

    /// Identifies the current run. Bumped on the main thread by `start`; main-thread UI
    /// updates posted by an older run are dropped, so a quick stop-then-start (switching
    /// profiles) can't be clobbered by the previous run's late updates.
    private var runToken = 0
    private var activeToken = 0  // queue-confined copy of `runToken`

    private func onMain(_ token: Int, _ work: @escaping (ClickEngine) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.runToken == token else { return }
            work(self)
        }
    }

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
        activeTargetIndex = 0
        startDate = Date()
        isRunning = true
        runToken += 1
        let token = runToken

        queue.async { [weak self] in
            guard let self = self else { return }
            self.activeToken = token
            self.config = config
            self.running = true
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

    /// Completely stops and tears down the engine.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        activeTargetIndex = 0
        let token = runToken

        queue.async { [weak self] in
            guard let self = self else { return }
            let finalCount = self.localClickCount
            self.teardown()
            self.onMain(token) { $0.clickCount = finalCount }
        }
    }

    // MARK: - Queue-confined helpers

    private func teardown() {
        running = false
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
        guard running, let timer = timer else { return }
        let deadline: DispatchTime = delay <= 0 ? .now() : (.now() + delay)
        timer.schedule(deadline: deadline, leeway: .nanoseconds(0))
    }

    // MARK: - Tick

    private func tick() {
        guard running, let config = config, !config.targets.isEmpty else { return }

        // --- Determine target coordinate for this tick ---
        let targetIndex = currentTargetIndex % config.targets.count
        let target = config.targets[targetIndex]
        let targetPoint = CGPoint(x: target.x, y: target.y)

        // --- Cursor-movement interrupt ---
        if config.cursorInterruptEnabled {
            let current = CGEvent(source: nil)?.location ?? .zero
            if let last = lastCursorPosition {
                let dx = current.x - last.x
                let dy = current.y - last.y
                if sqrt(dx * dx + dy * dy) > Constants.cursorInterruptThreshold {
                    let finalCount = localClickCount
                    teardown()
                    onMain(activeToken) { engine in
                        engine.clickCount = finalCount
                        engine.isRunning = false
                        engine.activeTargetIndex = 0
                        engine.engineError = .cursorInterrupt
                    }
                    return
                }
            }
        }

        // --- Move hardware cursor to the target coordinate ---
        CGWarpMouseCursorPosition(targetPoint)
        if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: targetPoint, mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
        if config.cursorInterruptEnabled {
            lastCursorPosition = targetPoint
        }

        // --- Click the current target ---
        postClick(at: targetPoint, button: config.button, action: config.action)

        localClickCount += 1
        let currentCount = localClickCount
        let currentIdx = targetIndex

        onMain(activeToken) { $0.activeTargetIndex = currentIdx }

        // --- Execution limit (runs N full cycles through all targets) ---
        if case .count(let cycles) = config.executionLimit {
            let totalNeeded = max(cycles, 1) * config.targets.count
            if currentCount >= totalNeeded {
                teardown()
                onMain(activeToken) { engine in
                    engine.clickCount = currentCount
                    engine.isRunning = false
                    engine.activeTargetIndex = 0
                }
                return
            }
        }

        currentTargetIndex = (targetIndex + 1) % config.targets.count

        // --- Throttled UI counter update (~30 FPS) ---
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastUIUpdateTime >= 0.033 {
            lastUIUpdateTime = now
            onMain(activeToken) { $0.clickCount = currentCount }
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

            if clickCount > 1 {
                // Realistic ~10ms button-down hold for multi-click recognition
                usleep(10_000)
            }

            up.post(tap: .cghidEventTap)

            if state < clickCount {
                // Realistic ~20ms gap between successive clicks (well within macOS 500ms threshold)
                usleep(20_000)
            }
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
