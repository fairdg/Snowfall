import AppKit

private final class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayWindowManager {
    private var overlays: [(window: NSPanel, renderer: SnowRenderer)] = []
    func apply(settings: SettingsManager) {
        guard settings.isEnabled else {
            stop()
            return
        }
        if overlays.isEmpty {
            rebuild(settings: settings)
        } else {
            let parameters = SnowParameters(intensity: settings.intensity, speed: settings.speed, wind: settings.wind)
            overlays.forEach { $0.renderer.update(parameters: parameters) }
        }
    }

    func rebuild(settings: SettingsManager) {
        stop()
        guard settings.isEnabled else { return }
        let screens = NSScreen.screens
        let budget = max(1, 1800 / max(1, screens.count))
        for screen in screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.hidesOnDeactivate = false
            window.isFloatingPanel = true
            window.level = .floating
            // Below system menus; not a full-screen auxiliary window.
            window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenNone]
            window.animationBehavior = .none
            let renderer = SnowRenderer(frame: CGRect(origin: .zero, size: screen.frame.size))
            window.contentView = renderer
            window.setFrame(screen.frame, display: false)
            window.orderFrontRegardless()
            renderer.start(
                parameters: SnowParameters(intensity: settings.intensity, speed: settings.speed, wind: settings.wind),
                budget: budget
            )
            overlays.append((window, renderer))
        }
    }

    func stop() {
        for overlay in overlays {
            overlay.renderer.clear()
            overlay.window.orderOut(nil)
            overlay.window.contentView = nil
            overlay.window.close()
        }
        overlays.removeAll()
    }
}
