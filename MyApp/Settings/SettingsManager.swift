import Foundation
import Observation

@MainActor
@Observable
final class SettingsManager {
    var isEnabled = true {
        didSet { onChange?() }
    }
    var intensity: Double {
        didSet { defaults.set(intensity, forKey: "intensity"); onChange?() }
    }
    var speed: Double {
        didSet { defaults.set(speed, forKey: "speed"); onChange?() }
    }
    var wind: Double {
        didSet { defaults.set(wind, forKey: "wind"); onChange?() }
    }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["intensity": 0.45, "speed": 1.0, "wind": 0.15])
        intensity = Self.read(defaults, key: "intensity", range: 0.05...1, fallback: 0.45)
        speed = Self.read(defaults, key: "speed", range: 0.3...2.5, fallback: 1)
        wind = Self.read(defaults, key: "wind", range: -1...1, fallback: 0.15)
    }

    private static func read(_ defaults: UserDefaults, key: String,
                             range: ClosedRange<Double>, fallback: Double) -> Double {
        let value = defaults.double(forKey: key)
        return value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}
