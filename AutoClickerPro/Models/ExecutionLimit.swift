import Foundation

// MARK: - Execution Limit

/// Controls when the click engine stops automatically.
enum ExecutionLimit: Equatable {
    /// Run until the user manually stops.
    case infinite

    /// Stop after a specific number of clicks.
    case count(Int)

    var isInfinite: Bool {
        if case .infinite = self { return true }
        return false
    }

    var countValue: Int {
        switch self {
        case .infinite: return 0
        case .count(let n): return n
        }
    }
}
