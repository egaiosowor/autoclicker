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
        XCTAssertEqual(IntervalUnit.minutes.toSeconds(2), 120, accuracy: 1e-9)
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

final class MultiTargetTests: XCTestCase {
    func testMultiTargetSequence() {
        var config = ClickConfiguration()
        config.targets = [
            TargetPoint(x: 100, y: 100, delayMs: 10),
            TargetPoint(x: 200, y: 200, delayMs: 20),
            TargetPoint(x: 300, y: 300, delayMs: 30)
        ]
        config.executionLimit = .count(3)
        XCTAssertEqual(config.targets.count, 3)
        XCTAssertEqual(config.targets[0].x, 100)
        XCTAssertEqual(config.targets[1].x, 200)
        XCTAssertEqual(config.targets[2].x, 300)
    }
}

final class EngineMultiTargetExecutionTests: XCTestCase {
    func testEngineCyclesThroughMultipleTargets() {
        let engine = ClickEngine()
        var config = ClickConfiguration()
        config.intervalValue = 10
        config.intervalUnit = .milliseconds
        config.targets = [
            TargetPoint(x: 111, y: 111, delayMs: 0),
            TargetPoint(x: 222, y: 222, delayMs: 0),
            TargetPoint(x: 333, y: 333, delayMs: 0)
        ]
        // 2 cycles through 3 targets = 6 total clicks
        config.executionLimit = .count(2)
        
        let expectation = XCTestExpectation(description: "Engine completes 6 clicks across 3 targets")
        
        engine.start(config: config)
        
        // Wait up to 1 second for 6 clicks at 10ms each
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(engine.isRunning)
            XCTAssertEqual(engine.clickCount, 6)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
