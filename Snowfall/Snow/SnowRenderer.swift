import AppKit
import QuartzCore

@MainActor
final class SnowRenderer: NSView {
    override var isOpaque: Bool { false }
    private var engine: SnowEngine?
    private var frameLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var particles: [CALayer] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    func start(parameters: SnowParameters, budget: Int) {
        clear()
        engine = SnowEngine(size: bounds.size, parameters: parameters, budget: budget)
        drawParticles()
        let link = displayLink(target: self, selector: #selector(frame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        frameLink = link
    }

    func update(parameters: SnowParameters) {
        engine?.update(parameters: parameters)
    }

    @objc private func frame(_ link: CADisplayLink) {
        let timestamp = link.targetTimestamp
        defer { lastTimestamp = timestamp }
        guard let previous = lastTimestamp else { return }
        engine?.advance(by: timestamp - previous)
        drawParticles()
    }

    private func drawParticles() {
        guard let engine, let root = layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        while particles.count > engine.flakes.count {
            particles.removeLast().removeFromSuperlayer()
        }
        while particles.count < engine.flakes.count {
            let flake = engine.flakes[particles.count]
            let particle = CALayer()
            particle.bounds = CGRect(x: 0, y: 0, width: flake.diameter, height: flake.diameter)
            particle.cornerRadius = flake.diameter / 2
            particle.backgroundColor = NSColor.white.cgColor
            particle.contentsScale = window?.backingScaleFactor ?? 2
            root.addSublayer(particle)
            particles.append(particle)
        }
        for (index, flake) in engine.flakes.enumerated() {
            particles[index].position = flake.position
            particles[index].opacity = flake.opacity * Float(flake.visibility)
        }
        CATransaction.commit()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        particles.forEach { $0.contentsScale = scale }
    }

    func clear() {
        frameLink?.invalidate()
        frameLink = nil
        lastTimestamp = nil
        engine = nil
        particles.forEach { $0.removeFromSuperlayer() }
        particles.removeAll()
    }
}
