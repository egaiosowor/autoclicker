import Carbon
import Cocoa
import CoreGraphics
import Foundation

// MARK: - Hotkey Action

enum HotkeyAction {
    case toggleStartStop
    case stopOnly
}

// MARK: - Hotkey Manager

/// Installs a system-wide CGEventTap to capture global hotkeys (requires Accessibility permission).
final class HotkeyManager: ObservableObject {

    /// Called on the main thread when a hotkey fires.
    var onHotkey: ((HotkeyAction) -> Void)?

    @Published private(set) var isListening = false

    private let lock = NSLock()
    private var cachedStartStopCombo: KeyCombo

    @Published var startStopCombo: KeyCombo {
        didSet {
            lock.withLock { cachedStartStopCombo = startStopCombo }
            saveCombos()
        }
    }

    /// True when the last attempt to install the event tap failed (Accessibility missing).
    @Published private(set) var tapFailed = false

    // Lifecycle state, guarded by `lock`.
    private enum TapState { case idle, starting, listening }
    private var tapState: TapState = .idle
    private var generation = 0
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var threadRunLoop: CFRunLoop?

    private static let startStopKey = "AutoClicker.Hotkey.StartStop"

    init() {
        let loadedStartStop = Self.loadCombo(forKey: Self.startStopKey) ?? Constants.defaultStartStopCombo
        self.cachedStartStopCombo = loadedStartStop
        self.startStopCombo = loadedStartStop
    }

    // MARK: - Persistence

    private func saveCombos() {
        if let data = try? JSONEncoder().encode(startStopCombo) {
            UserDefaults.standard.set(data, forKey: Self.startStopKey)
        }
    }

    private static func loadCombo(forKey key: String) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) else {
            return nil
        }
        return combo
    }

    func resetToDefaults() {
        startStopCombo = Constants.defaultStartStopCombo
    }

    func setToF6Defaults() {
        startStopCombo = Constants.defaultF6StartStopCombo
    }

    // MARK: - Validation

    /// Returns a user-facing error if `combo` is not allowed.
    func validate(_ combo: KeyCombo) -> String? {
        if combo.modifierFlags.isEmpty && !combo.isFunctionKey {
            return "Use at least one modifier (⌘ ⌥ ⌃ ⇧) or a function key."
        }
        return nil
    }

    // MARK: - Start / Stop

    /// Idempotent: does nothing if a tap is already starting or running.
    func startListening() {
        lock.lock()
        guard tapState == .idle else { lock.unlock(); return }
        tapState = .starting
        generation += 1
        let myGeneration = generation
        lock.unlock()

        // The thread holds `self` strongly until its run loop exits, so the
        // unretained pointer handed to the tap callback stays valid.
        let thread = Thread { [self] in
            self.runTap(generation: myGeneration)
        }
        thread.name = "HotkeyManager"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func stopListening() {
        lock.lock()
        generation += 1
        let tap = eventTap
        let source = runLoopSource
        let runLoop = threadRunLoop
        eventTap = nil
        runLoopSource = nil
        threadRunLoop = nil
        tapState = .idle
        lock.unlock()

        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = source { CFRunLoopSourceInvalidate(source) }
        if let runLoop = runLoop { CFRunLoopStop(runLoop) }
        publish(listening: false, failed: false)
    }

    private func publish(listening: Bool, failed: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isListening = listening
            self?.tapFailed = failed
        }
    }

    /// Runs on the dedicated tap thread.
    private func runTap(generation myGeneration: Int) {
        guard let (tap, source) = createTap() else {
            lock.lock()
            if generation == myGeneration { tapState = .idle }
            lock.unlock()
            publish(listening: false, failed: true)
            return
        }

        let runLoop = CFRunLoopGetCurrent()
        lock.lock()
        guard generation == myGeneration else {
            // stopListening() ran while we were starting; discard this tap.
            lock.unlock()
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopSourceInvalidate(source)
            return
        }
        eventTap = tap
        runLoopSource = source
        threadRunLoop = runLoop
        tapState = .listening
        lock.unlock()

        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        publish(listening: true, failed: false)
        CFRunLoopRun()
    }

    // MARK: - CGEventTap Installation

    private func createTap() -> (CFMachPort, CFRunLoopSource)? {
        // We capture key-down events globally.
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // The callback must be a C-function pointer, so we pass `self` as userInfo.
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

            // If the tap gets disabled by macOS, re-enable it.
            if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                manager.lock.lock()
                let tap = manager.eventTap
                manager.lock.unlock()
                if let tap = tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            // Emergency stop with Escape key (does not swallow Escape so other apps still work)
            if keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async { manager.onHotkey?(.stopOnly) }
                return Unmanaged.passUnretained(event)
            }

            let startStop = manager.lock.withLock { manager.cachedStartStopCombo }

            // Match configured Start / Stop shortcut
            if startStop.matches(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async { manager.onHotkey?(.toggleStartStop) }
                return nil  // swallow the event
            }

            return Unmanaged.passUnretained(event)
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPointer
        ) else {
            print("[HotkeyManager] Failed to create event tap. Accessibility permission may not be granted.")
            return nil
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        return (tap, source!)
    }
}
