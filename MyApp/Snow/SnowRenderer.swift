import AppKit
import QuartzCore

@MainActor
final class SnowRenderer: NSView {
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    func render(_ flakes: [Snowflake], scale: CGFloat) {
        clear()
        guard let root = layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for flake in flakes {
            let particle = CALayer()
            particle.bounds = CGRect(x: 0, y: 0, width: flake.diameter, height: flake.diameter)
            particle.cornerRadius = flake.diameter / 2
            particle.backgroundColor = NSColor.white.cgColor
            particle.opacity = flake.opacity
            particle.contentsScale = scale
            particle.position = CGPoint(x: -20, y: -20)
            root.addSublayer(particle)

            let fall = CAKeyframeAnimation(keyPath: "position")
            fall.values = flake.positions.map { NSValue(point: $0) }
            fall.duration = flake.duration
            // Distribute particles along their paths immediately on launch.
            fall.timeOffset = flake.phase
            fall.repeatCount = .infinity
            fall.calculationMode = .linear
            particle.add(fall, forKey: "snowfall")
        }
        CATransaction.commit()
    }

    func clear() {
        layer?.sublayers?.forEach {
            $0.removeAllAnimations()
            $0.removeFromSuperlayer()
        }
    }
}
