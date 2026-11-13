import CoreGraphics

/// Swept collision with horizontal surfaces prevents fast particles tunnelling through windows.
struct SnowCollision {
    static func firstContact(from start: CGPoint, to end: CGPoint, radius: CGFloat,
                             edges: [WindowTopEdge]) -> CGPoint? {
        guard end.y < start.y else { return nil }
        var earliest: CGFloat = 2
        var contact: CGPoint?
        for edge in edges {
            let centerY = edge.y + radius
            guard start.y >= centerY, end.y <= centerY else { continue }
            let fraction = (start.y - centerY) / (start.y - end.y)
            let x = start.x + (end.x - start.x) * fraction
            guard x >= edge.startX, x <= edge.endX, fraction < earliest else { continue }
            earliest = fraction
            contact = CGPoint(x: x, y: centerY)
        }
        return contact
    }

    static func localEdges(from windows: [TrackedWindow], in frame: CGRect) -> [WindowTopEdge] {
        windows.flatMap(\.exposedTopEdges).compactMap { edge in
            guard edge.y > frame.minY, edge.y <= frame.maxY else { return nil }
            let start = max(edge.startX, frame.minX)
            let end = min(edge.endX, frame.maxX)
            guard start < end else { return nil }
            return WindowTopEdge(startX: start - frame.minX, endX: end - frame.minX,
                                 y: edge.y - frame.minY)
        }
    }
}
