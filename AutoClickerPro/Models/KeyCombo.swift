import AppKit
import Carbon
import CoreGraphics
import Foundation

// MARK: - Key Combo Model

/// Represents a configurable keyboard shortcut (modifier flags + key code).
struct KeyCombo: Codable, Equatable, Hashable {
    var keyCode: UInt16
    var modifiers: UInt

    // MARK: - Initializers

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        self.keyCode = keyCode
        let relevant = modifiers.intersection([.command, .shift, .option, .control])
        self.modifiers = relevant.rawValue
    }

    init(keyCode: UInt16, cgFlags: CGEventFlags) {
        self.keyCode = keyCode
        var mods: NSEvent.ModifierFlags = []
        if cgFlags.contains(.maskCommand) { mods.insert(.command) }
        if cgFlags.contains(.maskShift) { mods.insert(.shift) }
        if cgFlags.contains(.maskAlternate) { mods.insert(.option) }
        if cgFlags.contains(.maskControl) { mods.insert(.control) }
        self.modifiers = mods.rawValue
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }

    /// True for F1–F20, which are safe to use without a modifier.
    var isFunctionKey: Bool {
        let fKeys: Set<Int> = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                               kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
        return fKeys.contains(Int(keyCode))
    }

    // MARK: - Matching

    /// Matches against an incoming CGEvent's keycode and flags.
    /// Safely ignores device-specific flags (Fn key, CapsLock, numeric pad).
    func matches(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        guard self.keyCode == keyCode else { return false }

        let hasCmd = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)
        let hasAlt = flags.contains(.maskAlternate)
        let hasCtrl = flags.contains(.maskControl)

        let expected = modifierFlags
        let expectCmd = expected.contains(.command)
        let expectShift = expected.contains(.shift)
        let expectAlt = expected.contains(.option)
        let expectCtrl = expected.contains(.control)

        return hasCmd == expectCmd
            && hasShift == expectShift
            && hasAlt == expectAlt
            && hasCtrl == expectCtrl
    }

    // MARK: - Display

    /// Human-readable representation, e.g. "⌥⌘S" or "F6" or "⇧F6"
    var displayString: String {
        var symbols = ""
        if modifierFlags.contains(.control) { symbols += "⌃" }
        if modifierFlags.contains(.option) { symbols += "⌥" }
        if modifierFlags.contains(.shift) { symbols += "⇧" }
        if modifierFlags.contains(.command) { symbols += "⌘" }

        let key = KeyCombo.stringForKeyCode(keyCode)
        if symbols.isEmpty {
            return key
        }
        return "\(symbols) \(key)"
    }

    // MARK: - KeyCode to String Lookup

    static func stringForKeyCode(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        // Function keys
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"

        // Navigation & Editing
        case kVK_Return: return "↩ Return"
        case kVK_Tab: return "⇥ Tab"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫ Delete"
        case kVK_ForwardDelete: return "⌦ Del"
        case kVK_Escape: return "⎋ Esc"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_Home: return "↖ Home"
        case kVK_Help: return "Help"
        case kVK_End: return "End"
        case kVK_PageUp: return "⇞ PageUp"
        case kVK_PageDown: return "⇟ PageDown"

        // Letters
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"

        // Numbers
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"

        // Punctuation & Symbols
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Grave: return "`"

        default:
            return "Key(\(keyCode))"
        }
    }
}

