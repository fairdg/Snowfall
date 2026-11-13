import CoreGraphics

struct WindowIdentity: Hashable {
    let processID: Int32
    let windowID: CGWindowID
}

/// Coordinates are global AppKit points: Y increases upwards.
struct WindowTopEdge: Equatable {
    let startX: CGFloat
    let endX: CGFloat
    let y: CGFloat
}

struct TrackedWindow: Equatable, Identifiable {
    let id: WindowIdentity
    let frame: CGRect
    let stackingIndex: Int
    let exposedTopEdges: [WindowTopEdge]
}

struct WindowChanges {
    var appeared: Set<WindowIdentity> = []
    var disappeared: Set<WindowIdentity> = []
    var updated: Set<WindowIdentity> = []
}
