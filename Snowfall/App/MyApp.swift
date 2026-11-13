import AppKit

@main
enum MyApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let coordinator = AppCoordinator()
        application.setActivationPolicy(.accessory)
        application.delegate = coordinator
        withExtendedLifetime(coordinator) {
            application.run()
        }
    }
}
