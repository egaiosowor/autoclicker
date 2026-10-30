import CoreGraphics
import Foundation

// MARK: - Target Point

/// A fixed screen coordinate target with an individual wait delay.
struct TargetPoint: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var x: Double = 0
    var y: Double = 0
    /// Extra wait (ms) added to the global interval after clicking this target.
    var delayMs: Double = 0
}
