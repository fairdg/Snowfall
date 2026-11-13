import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings: SettingsManager
    private let showSettings: () -> Void
    private let toggleItem = NSMenuItem(title: "Снегопад", action: #selector(toggleSnow), keyEquivalent: "")
    private var choices: [(item: NSMenuItem, key: String, value: Double)] = []

    init(settings: SettingsManager, showSettings: @escaping () -> Void) {
        self.settings = settings
        self.showSettings = showSettings
        super.init()
        let image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Снегопад")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Снегопад"
        let menu = NSMenu()
        menu.delegate = self
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        addChoices(to: menu, title: "Интенсивность", key: "intensity",
                   values: [("Лёгкий снег", 0.15), ("Снегопад", 0.45), ("Метель", 1)])
        addChoices(to: menu, title: "Скорость", key: "speed",
                   values: [("Медленно", 0.5), ("Обычно", 1), ("Быстро", 2)])
        addChoices(to: menu, title: "Ветер", key: "wind",
                   values: [("Влево", -0.7), ("Штиль", 0), ("Вправо", 0.7)])
        menu.addItem(.separator())
        let preferences = NSMenuItem(title: "Настройки…", action: #selector(openSettings), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)
        let quit = NSMenuItem(title: "Выход", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func addChoices(to menu: NSMenu, title: String, key: String, values: [(String, Double)]) {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        for (label, value) in values {
            let item = NSMenuItem(title: label, action: #selector(selectValue(_:)), keyEquivalent: "")
            item.target = self
            item.tag = choices.count
            choices.append((item, key, value))
            submenu.addItem(item)
        }
        parent.submenu = submenu
        menu.addItem(parent)
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleItem.state = settings.isEnabled ? .on : .off
        for choice in choices {
            let current: Double
            switch choice.key {
            case "intensity": current = settings.intensity
            case "speed": current = settings.speed
            default: current = settings.wind
            }
            choice.item.state = abs(current - choice.value) < 0.001 ? .on : .off
        }
    }

    @objc private func selectValue(_ sender: NSMenuItem) {
        let choice = choices[sender.tag]
        switch choice.key {
        case "intensity": settings.intensity = choice.value
        case "speed": settings.speed = choice.value
        default: settings.wind = choice.value
        }
    }

    @objc private func toggleSnow() { settings.isEnabled.toggle() }
    @objc private func openSettings() { showSettings() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    func stop() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
}
