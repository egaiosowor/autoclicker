import Foundation

// MARK: - Click Action

/// How many rapid clicks constitute one action.
enum ClickAction: Int, CaseIterable, Identifiable {
    case single = 1
    case double = 2
    case triple = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .double: return "Double"
        case .triple: return "Triple"
        }
    }

    var shortLabel: String {
        switch self {
        case .single: return "1×"
        case .double: return "2×"
        case .triple: return "3×"
        }
    }
}
