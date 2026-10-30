import Carbon
import XCTest
@testable import AutoClickerPro

final class KeyComboTests: XCTestCase {
    func testMatchesIgnoringHardwareFlags() {
        let combo = KeyCombo(keyCode: UInt16(kVK_ANSI_S), modifiers: [.option, .command])
        XCTAssertTrue(combo.matches(keyCode: UInt16(kVK_ANSI_S), flags: [.maskCommand, .maskAlternate]))
        XCTAssertTrue(combo.matches(keyCode: UInt16(kVK_ANSI_S),
                                    flags: [.maskCommand, .maskAlternate, .maskSecondaryFn, .maskNumericPad]))
    }

    func testRejectsWrongModifiersOrKey() {
        let combo = KeyCombo(keyCode: UInt16(kVK_ANSI_S), modifiers: [.option, .command])
        XCTAssertFalse(combo.matches(keyCode: UInt16(kVK_ANSI_S), flags: [.maskCommand]))
        XCTAssertFalse(combo.matches(keyCode: UInt16(kVK_ANSI_S), flags: [.maskCommand, .maskAlternate, .maskShift]))
        XCTAssertFalse(combo.matches(keyCode: UInt16(kVK_ANSI_P), flags: [.maskCommand, .maskAlternate]))
    }

    func testFunctionKeyDetection() {
        XCTAssertTrue(KeyCombo(keyCode: UInt16(kVK_F6)).isFunctionKey)
        XCTAssertFalse(KeyCombo(keyCode: UInt16(kVK_ANSI_S)).isFunctionKey)
    }
}

final class HotkeyValidationTests: XCTestCase {
    func testValidation() {
        let manager = HotkeyManager()
        XCTAssertNotNil(manager.validate(KeyCombo(keyCode: UInt16(kVK_ANSI_S)), for: .toggleStartStop),
                        "bare letter must be rejected")
        XCTAssertNil(manager.validate(KeyCombo(keyCode: UInt16(kVK_F8)), for: .toggleStartStop))
        XCTAssertNotNil(manager.validate(manager.pauseResumeCombo, for: .toggleStartStop),
                        "duplicate of the other action must be rejected")
    }
}

final class IntervalTests: XCTestCase {
    func testUnitConversion() {
        XCTAssertEqual(IntervalUnit.milliseconds.toSeconds(250), 0.25, accuracy: 1e-9)
        XCTAssertEqual(IntervalUnit.seconds.toSeconds(2), 2, accuracy: 1e-9)
        XCTAssertEqual(IntervalUnit.minutes.toSeconds(2), 120, accuracy: 1e-9)
        XCTAssertEqual(IntervalUnit.hours.toSeconds(1), 3600, accuracy: 1e-9)
    }

    func testSafetyGuard() {
        XCTAssertFalse(SafetyGuard.validateInterval(0.0005))
        XCTAssertTrue(SafetyGuard.validateInterval(0.001))
        XCTAssertNotNil(SafetyGuard.intervalWarning(0.0015))
        XCTAssertNil(SafetyGuard.intervalWarning(0.1))
    }
}

final class EngineValidationTests: XCTestCase {
    func testRefusesTooFastInterval() {
        let engine = ClickEngine()
        var config = ClickConfiguration()
        config.intervalValue = 0.1
        config.intervalUnit = .milliseconds
        engine.start(config: config)
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.engineError, .intervalTooFast(0.0001))
    }

    func testRefusesNoTargets() {
        let engine = ClickEngine()
        var config = ClickConfiguration()
        config.targets = []
        engine.start(config: config)
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.engineError, .noTargets)
    }
}
