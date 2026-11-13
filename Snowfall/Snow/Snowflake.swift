import CoreGraphics

struct Snowflake {
    var position: CGPoint
    let diameter: CGFloat
    let opacity: Float
    let fallSpeed: Double
    let swayAmplitude: Double
    let swayFrequency: Double
    var phase: Double
    var visibility: Double
}
