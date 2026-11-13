import Foundation
import CoreGraphics

/// Value parameters keep simulation independent of settings persistence and UI.
struct SnowParameters {
    var intensity: Double
    var speed: Double
    var wind: Double
}

@MainActor
struct SnowEngine {
    private(set) var flakes: [Snowflake] = []
    private(set) var currentSpeed: Double
    private(set) var currentWind: Double
    private var target: SnowParameters
    private let size: CGSize
    private let budget: Int
    private var targetCount: Int
    private var spawnCredit = 0.0

    init(size: CGSize, parameters: SnowParameters, budget: Int) {
        self.size = size
        self.budget = max(0, budget)
        target = parameters
        currentSpeed = parameters.speed
        currentWind = parameters.wind
        targetCount = Self.count(size: size, intensity: parameters.intensity, budget: max(0, budget))
        flakes = (0..<targetCount).map { _ in Self.makeFlake(size: size, initial: true) }
    }

    mutating func update(parameters: SnowParameters) {
        target = parameters
        targetCount = Self.count(size: size, intensity: parameters.intensity, budget: budget)
    }

    mutating func advance(by elapsed: Double) {
        guard elapsed.isFinite, elapsed > 0 else { return }
        // Do not jump across the screen after sleep, a debugger stop or a Space transition.
        let dt = min(elapsed, 1.0 / 15)
        let blend = 1 - exp(-dt / 0.65)
        currentSpeed += (target.speed - currentSpeed) * blend
        currentWind += (target.wind - currentWind) * blend

        if flakes.count < targetCount {
            spawnCredit += dt * max(20, Double(targetCount) / 1.2)
            let added = min(targetCount - flakes.count, Int(spawnCredit))
            spawnCredit -= Double(added)
            for _ in 0..<added {
                flakes.append(Self.makeFlake(size: size, initial: false))
            }
        } else {
            spawnCredit = 0
        }

        for index in flakes.indices {
            let desiredVisibility = index < targetCount ? 1.0 : 0.0
            let delta = dt / 0.65
            if flakes[index].visibility < desiredVisibility {
                flakes[index].visibility = min(desiredVisibility, flakes[index].visibility + delta)
            } else {
                flakes[index].visibility = max(desiredVisibility, flakes[index].visibility - delta)
            }
            flakes[index].phase += flakes[index].swayFrequency * dt
            let sway = flakes[index].swayAmplitude * cos(flakes[index].phase)
            flakes[index].position.x += (currentWind * 85 + sway) * dt
            flakes[index].position.y -= flakes[index].fallSpeed * currentSpeed * dt

            // Recycling occurs outside the visible area, never when settings change.
            if flakes[index].position.y < -16 {
                flakes[index].position.y = size.height + 16
                flakes[index].position.x = Double.random(in: 0...max(1, size.width))
            }
            if flakes[index].position.x < -16 {
                flakes[index].position.x = size.width + 16
            } else if flakes[index].position.x > size.width + 16 {
                flakes[index].position.x = -16
            }
        }
        while flakes.count > targetCount, flakes.last?.visibility == 0 {
            flakes.removeLast()
        }
    }

    private static func count(size: CGSize, intensity: Double, budget: Int) -> Int {
        min(budget, max(20, Int(360 * size.width * size.height / (1440 * 900) * intensity)))
    }

    private static func makeFlake(size: CGSize, initial: Bool) -> Snowflake {
        let depth = Double.random(in: 0.25...1)
        return Snowflake(
            position: CGPoint(x: Double.random(in: 0...max(1, size.width)),
                              y: initial ? Double.random(in: 0...max(1, size.height)) : size.height + 16),
            diameter: 1.5 + depth * 4,
            opacity: Float(0.35 + depth * 0.6),
            fallSpeed: 35 + 85 * depth,
            swayAmplitude: Double.random(in: 5...18),
            swayFrequency: Double.random(in: 0.5...1.5),
            phase: Double.random(in: 0...(2 * .pi)),
            visibility: initial ? 1 : 0
        )
    }
}
