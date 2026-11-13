import Foundation
import CoreGraphics

struct SnowImpact {
    let windowID: WindowIdentity
    let x: CGFloat
    let diameter: CGFloat
}

/// One shared model for all displays. Heights are stored relative to each window.
@MainActor
final class SnowAccumulationEngine {
    struct Drift {
        var frame: CGRect
        var heights: [CGFloat]
    }

    struct Scene {
        var surfaces: [WindowTopEdge] = []
        var polygons: [[CGPoint]] = []
    }

    let maximumHeight: CGFloat = 24
    private(set) var drifts: [WindowIdentity: Drift] = [:]
    private(set) var revision: UInt64 = 0
    private var windows: [TrackedWindow] = []
    var isEnabled = true {
        didSet {
            if oldValue != isEnabled { clear() }
        }
    }

    func update(windows: [TrackedWindow]) {
        guard self.windows != windows else { return }
        self.windows = windows
        let ids = Set(windows.map(\.id))
        drifts = drifts.filter { ids.contains($0.key) }
        for window in windows {
            let count = min(512, max(2, Int(ceil(window.frame.width / 8)) + 1))
            if var drift = drifts[window.id] {
                if drift.heights.count != count {
                    let old = drift.heights
                    drift.heights = (0..<count).map { index in
                        Self.sample(old, fraction: CGFloat(index) / CGFloat(count - 1))
                    }
                }
                drift.frame = window.frame
                drifts[window.id] = drift
            } else {
                drifts[window.id] = Drift(frame: window.frame, heights: Array(repeating: 0, count: count))
            }
        }
        revision &+= 1
    }

    func clear() {
        for id in Array(drifts.keys) {
            guard var drift = drifts[id] else { continue }
            drift.heights = Array(repeating: 0, count: drift.heights.count)
            drifts[id] = drift
        }
        revision &+= 1
    }

    func deposit(_ impacts: [SnowImpact]) {
        guard isEnabled, !impacts.isEmpty else { return }
        var changed = false
        for impact in impacts {
            guard var drift = drifts[impact.windowID], drift.frame.width > 0 else { continue }
            let x = impact.x - drift.frame.minX
            guard x >= 0, x <= drift.frame.width else { continue }
            let spread = max(12, impact.diameter * 4)
            for index in drift.heights.indices {
                let sampleX = CGFloat(index) / CGFloat(drift.heights.count - 1) * drift.frame.width
                let distance = abs(sampleX - x) / spread
                guard distance < 1 else { continue }
                // Smooth bell-shaped deposit: random landing positions create an uneven surface.
                let weight = (1 + cos(distance * .pi)) / 2
                let addition = impact.diameter * 0.32 * weight
                drift.heights[index] = min(maximumHeight, drift.heights[index] + addition)
            }
            drifts[impact.windowID] = drift
            changed = true
        }
        if changed { revision &+= 1 }
    }

    /// Produces only exposed portions, in the local coordinates of one display.
    func scene(in screen: CGRect) -> Scene {
        var scene = Scene()
        for window in windows {
            guard let drift = drifts[window.id] else { continue }
            let baseY = window.frame.maxY
            guard baseY > screen.minY, baseY <= screen.maxY else { continue }
            for edge in window.exposedTopEdges {
                let lower = max(edge.startX, screen.minX)
                let upper = min(edge.endX, screen.maxX)
                guard lower < upper else { continue }
                let count = max(1, Int(ceil((upper - lower) / 8)))
                var top: [CGPoint] = []
                for index in 0...count {
                    let x = lower + (upper - lower) * CGFloat(index) / CGFloat(count)
                    let fraction = (x - window.frame.minX) / max(1, window.frame.width)
                    var height = isEnabled ? Self.sample(drift.heights, fraction: fraction) : 0
                    // Avoid drawing a raised drift over the bottom of a foreground window.
                    for front in windows where front.stackingIndex < window.stackingIndex {
                        if x >= front.frame.minX && x <= front.frame.maxX && front.frame.maxY > baseY {
                            height = min(height, max(0, front.frame.minY - baseY))
                        }
                    }
                    top.append(CGPoint(x: x - screen.minX, y: baseY + height - screen.minY))
                }
                for index in 0..<count {
                    // Small horizontal collision strips follow the visible drift profile.
                    scene.surfaces.append(WindowTopEdge(
                        startX: top[index].x, endX: top[index + 1].x,
                        y: (top[index].y + top[index + 1].y) / 2, windowID: window.id
                    ))
                }
                if isEnabled && top.contains(where: { $0.y > baseY - screen.minY + 0.01 }) {
                    scene.polygons.append(
                        [CGPoint(x: lower - screen.minX, y: baseY - screen.minY)]
                        + top + [CGPoint(x: upper - screen.minX, y: baseY - screen.minY)]
                    )
                }
            }
        }
        return scene
    }

    private static func sample(_ heights: [CGFloat], fraction: CGFloat) -> CGFloat {
        let position = min(1, max(0, fraction)) * CGFloat(heights.count - 1)
        let lower = Int(position)
        let upper = min(heights.count - 1, lower + 1)
        return heights[lower] + (heights[upper] - heights[lower]) * (position - CGFloat(lower))
    }
}
