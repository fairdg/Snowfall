import AppKit
import CoreGraphics
import Observation

@MainActor
@Observable
final class WindowTracker: NSObject {
    private(set) var windows: [TrackedWindow] = []
    private(set) var changes = WindowChanges()
    private(set) var isRunning = false
    private(set) var queryFailed = false
    @ObservationIgnored var onChange: (([TrackedWindow]) -> Void)?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refresh), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
        refresh()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
                guard let self else { return }
                self.refresh()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        isRunning = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        publish([])
        queryFailed = false
    }

    @objc func refresh() {
        guard isRunning else { return }
        // Ignore only our click-through overlays. Our settings window still occludes other windows.
        let ignored = Set(NSApp.windows.filter { $0.ignoresMouseEvents }.map { CGWindowID($0.windowNumber) })
        guard let primary = NSScreen.screens.first,
              let descriptions = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
              ) as? [[String: Any]] else {
            queryFailed = true
            publish([])
            return
        }
        queryFailed = false
        let entries = descriptions.compactMap { info -> WindowGeometry.Entry? in
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                  let pid = info[kCGWindowOwnerPID as String] as? NSNumber,
                  let layer = info[kCGWindowLayer as String] as? NSNumber,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.origin.x.isFinite, rect.origin.y.isFinite,
                  rect.width.isFinite, rect.height.isFinite else { return nil }
            let id = number.uint32Value
            if pid.int32Value == ProcessInfo.processInfo.processIdentifier && ignored.contains(id) {
                return nil
            }
            return WindowGeometry.Entry(
                id: WindowIdentity(processID: pid.int32Value, windowID: id),
                frame: WindowGeometry.appKitFrame(from: rect, primaryScreenHeight: primary.frame.maxY),
                layer: layer.intValue,
                alpha: (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            )
        }
        publish(WindowGeometry.resolve(entries, screens: NSScreen.screens.map(\.frame),
                                       ownProcessID: ProcessInfo.processInfo.processIdentifier))
    }

    private func publish(_ snapshot: [TrackedWindow]) {
        let previous = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        let next = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id, $0) })
        let oldIDs = Set(previous.keys)
        let newIDs = Set(next.keys)
        changes = WindowChanges(
            appeared: newIDs.subtracting(oldIDs),
            disappeared: oldIDs.subtracting(newIDs),
            updated: newIDs.intersection(oldIDs).filter { previous[$0] != next[$0] }
        )
        if windows != snapshot {
            windows = snapshot
            onChange?(snapshot)
        }
    }
}
