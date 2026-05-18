import SwiftUI
import AppKit
import UserNotifications

@main
struct QuarantineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Accessory app: the real UI is the NSStatusItem/NSPopover the
        // delegate manages. This scene stays empty/never shown.
        Settings { EmptyView() }
    }

    /// Resolve a bundled resource: Bundle.main (signed .app, flattened
    /// into Contents/Resources by make-app.sh) first, then
    /// Bundle.module (dev `swift run`).
    static func resourceURL(_ name: String, _ ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.module.url(forResource: name, withExtension: ext)
    }

    /// Brand tray glyph, set as a template so macOS tints it for the
    /// active menu-bar appearance (dark on light bars, light on dark).
    /// Falls back to the prior SF Symbol if the bundled art is
    /// missing for any reason.
    static let menuBarIcon: NSImage = {
        let image: NSImage
        if let url = resourceURL("MenuBarIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = NSImage(
                systemSymbolName: "arrow.down.circle",
                accessibilityDescription: "Quarantine"
            ) ?? NSImage()
        }
        let height: CGFloat = 18
        let aspect = image.size.width / max(image.size.height, 1)
        image.size = NSSize(width: height * aspect, height: height)
        image.isTemplate = true
        return image
    }()

    /// In-app branding glyph (the full-colour app icon).
    static let appIcon: NSImage = {
        if let url = resourceURL("AppIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            return loaded
        }
        return NSImage(
            systemSymbolName: "arrow.down.circle.fill",
            accessibilityDescription: "Quarantine"
        ) ?? NSImage()
    }()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let store = QuarantineStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = QuarantineApp.menuBarIcon
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environment(store)
        )

        store.start()

        UNUserNotificationCenter.current().delegate = self
        Notifier.requestAuthorization()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let key = response.notification.request.content.userInfo["quarantineKey"] as? String
        DispatchQueue.main.async {
            self.store.focusedKey = key
            self.showPopover()
        }
        completionHandler()
    }
}
