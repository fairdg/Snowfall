import AppKit
import SwiftUI

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let settings = SettingsManager()
    private let overlays = OverlayWindowManager()
    private var menuBar: MenuBarController?
    private var settingsWindow: NSWindow?
    private var pendingUpdate: Task<Void, Never>?
    private var displaySleeping = false
    private var sessionInactive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(settings: settings) { [weak self] in
            self?.openSettings()
        }
        settings.onChange = { [weak self] in self?.scheduleUpdate() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(sleepDisplay),
                              name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(wakeDisplay),
                              name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(deactivateSession),
                              name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(activateSession),
                              name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        updateSnow()
    }

    private func scheduleUpdate() {
        pendingUpdate?.cancel()
        if !settings.isEnabled {
            overlays.stop()
            return
        }
        // Coalesce slider changes rather than rebuilding hundreds of layers per event.
        pendingUpdate = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(120)) }
            catch { return }
            self?.updateSnow()
        }
    }

    private func updateSnow() {
        guard !displaySleeping, !sessionInactive else {
            overlays.stop()
            return
        }
        overlays.rebuild(settings: settings)
    }

    @objc private func screensChanged() { scheduleUpdate() }
    @objc private func sleepDisplay() { displaySleeping = true; overlays.stop() }
    @objc private func wakeDisplay() { displaySleeping = false; updateSnow() }
    @objc private func deactivateSession() { sessionInactive = true; overlays.stop() }
    @objc private func activateSession() { sessionInactive = false; updateSnow() }

    private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Снегопад"
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        pendingUpdate?.cancel()
        settings.onChange = nil
        overlays.stop()
        menuBar?.stop()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
