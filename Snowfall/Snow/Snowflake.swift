import CoreGraphics

struct Snowflake {
    var position: CGPoint
    var velocity: CGVector = .zero
    let diameter: CGFloat
    let opacity: Float
    let fallSpeed: Double
    let swayAmplitude: Double
    let swayFrequency: Double
    var phase: Double
    var visibility: Double
}
