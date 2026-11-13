import CoreGraphics
import Foundation

/// A complete trajectory for the MVP. Window collisions will require live simulation.
struct Snowflake {
    let diameter: CGFloat
    let opacity: Float
    let duration: TimeInterval
    let phase: TimeInterval
    let positions: [CGPoint]
}
