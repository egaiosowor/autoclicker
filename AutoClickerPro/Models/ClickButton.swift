import CoreGraphics

// MARK: - Click Button

/// Which mouse button to simulate.
enum ClickButton: String, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    case middle = "Middle"

    var id: String { rawValue }

    /// Maps to the CoreGraphics mouse button constant.
    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .middle: return .center
        }
    }

    /// The CGEventType for a mouse-down event with this button.
    var mouseDownType: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .middle: return .otherMouseDown
        }
    }

    /// The CGEventType for a mouse-up event with this button.
    var mouseUpType: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .middle: return .otherMouseUp
        }
    }
}
