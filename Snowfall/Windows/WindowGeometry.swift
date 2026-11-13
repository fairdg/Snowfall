import CoreGraphics

struct WindowGeometry {
    struct Entry {
        let id: WindowIdentity
        let frame: CGRect
        let layer: Int
        let alpha: Double
    }

    static func appKitFrame(from quartzFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: quartzFrame.minX, y: primaryScreenHeight - quartzFrame.maxY,
               width: quartzFrame.width, height: quartzFrame.height)
    }

    /// Input order must be front to back. Only normal application windows participate.
    /// Service overlays can cover the display with transparent content despite an alpha of 1.
    static func resolve(_ entries: [Entry], screens: [CGRect], ownProcessID: Int32) -> [TrackedWindow] {
        var blockers: [CGRect] = []
        var result: [TrackedWindow] = []
        for (index, entry) in entries.enumerated() {
            guard entry.layer == 0, entry.alpha > 0, entry.frame.width > 0, entry.frame.height > 0,
                  screens.contains(where: { $0.intersects(entry.frame) }) else { continue }
            if entry.id.processID != ownProcessID {
                let top = entry.frame.maxY
                var intervals: [ClosedRange<CGFloat>] = screens.compactMap { screen in
                    guard top > screen.minY, top <= screen.maxY else { return nil }
                    let lower = max(entry.frame.minX, screen.minX)
                    let upper = min(entry.frame.maxX, screen.maxX)
                    return lower < upper ? lower...upper : nil
                }
                // Merge overlapping screen regions (for example mirrored displays).
                intervals.sort { $0.lowerBound < $1.lowerBound }
                var merged: [ClosedRange<CGFloat>] = []
                for interval in intervals {
                    if let last = merged.last, last.upperBound >= interval.lowerBound {
                        merged[merged.count - 1] = last.lowerBound...max(last.upperBound, interval.upperBound)
                    } else {
                        merged.append(interval)
                    }
                }
                for blocker in blockers where blocker.minY < top && blocker.maxY >= top {
                    merged = merged.flatMap { segment -> [ClosedRange<CGFloat>] in
                        guard blocker.maxX > segment.lowerBound, blocker.minX < segment.upperBound else {
                            return [segment]
                        }
                        var remaining: [ClosedRange<CGFloat>] = []
                        if blocker.minX > segment.lowerBound {
                            remaining.append(segment.lowerBound...min(segment.upperBound, blocker.minX))
                        }
                        if blocker.maxX < segment.upperBound {
                            remaining.append(max(segment.lowerBound, blocker.maxX)...segment.upperBound)
                        }
                        return remaining
                    }
                }
                result.append(TrackedWindow(id: entry.id, frame: entry.frame, stackingIndex: index,
                    exposedTopEdges: merged.map {
                        WindowTopEdge(startX: $0.lowerBound, endX: $0.upperBound, y: top)
                    }))
            }
            blockers.append(entry.frame)
        }
        return result
    }
}
