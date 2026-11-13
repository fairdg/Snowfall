import Foundation
import CoreGraphics

@MainActor
struct SnowEngine {
    /// Bounded layer count, independent of display pixel density.
    func makeSnow(in size: CGSize, settings: SettingsManager, budget: Int) -> [Snowflake] {
        let area = size.width * size.height / (1440 * 900)
        let count = min(budget, max(20, Int(360 * area * settings.intensity)))
        return (0..<count).map { _ in
            let depth = Double.random(in: 0.25...1)
            let velocity = (35 + 85 * depth) * settings.speed
            let duration = (size.height + 32) / velocity
            let drift = settings.wind * 85 * duration
            let startX = Double.random(in: -max(0, drift)-30...size.width+max(0, -drift)+30)
            let amplitude = Double.random(in: 8...28)
            let frequency = Double.random(in: 1.5...4)
            let angle = Double.random(in: 0...(2 * .pi))
            let positions = (0...90).map { index in
                let progress = Double(index) / 90
                return CGPoint(
                    x: startX + drift * progress + amplitude * sin(progress * frequency * 2 * .pi + angle),
                    y: size.height + 16 - (size.height + 32) * progress
                )
            }
            return Snowflake(
                diameter: 1.5 + depth * 4,
                opacity: Float(0.35 + depth * 0.6),
                duration: duration,
                phase: Double.random(in: 0..<duration),
                positions: positions
            )
        }
    }
}
