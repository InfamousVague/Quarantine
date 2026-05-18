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

    /// Tray glyph: the macOS download symbol
    /// (`square.and.arrow.down`), a template so macOS tints it for
    /// the active menu-bar appearance. Vector SF Symbol — no bundled
    /// raster — so it stays crisp on Retina at any scale.
    static let menuBarIcon: NSImage = {
        let cfg = NSImage.SymbolConfiguration(
            pointSize: 15, weight: .regular)
        let image = (NSImage(
            systemSymbolName: "square.and.arrow.down",
            accessibilityDescription: "Quarantine"
        ) ?? NSImage()).withSymbolConfiguration(cfg) ?? NSImage()
        image.isTemplate = true
        return image
    }()

    /// The same glyph at full resolution, kept as a template so
    /// SwiftUI `.foregroundStyle(...)` can tint it cleanly in the
    /// panel header — the way Espresso/Alfred render their glyph in
    /// the brand accent. (Distinct from `menuBarIcon`, which is
    /// downscaled to ~18pt for the status bar.)
    static let trayGlyph: NSImage = {
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
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSPopoverDelegate {
    let store = QuarantineStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = QuarantineApp.menuBarIcon
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.delegate = self
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
        if let win = popover.contentViewController?.view.window {
            clampOnScreen(win, anchoredTo: button)
            win.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    /// Keep the popover fully on the screen that holds the status
    /// item. NSPopover centers on the icon and clips when the icon
    /// is near a screen edge (notably far right / next to the
    /// notch); shift the window back inside the visible frame.
    private func clampOnScreen(_ win: NSWindow, anchoredTo anchor: NSView) {
        guard let screen = anchor.window?.screen ?? NSScreen.main
        else { return }
        let vis = screen.visibleFrame
        let pad: CGFloat = 8
        var f = win.frame
        if f.maxX > vis.maxX - pad { f.origin.x = vis.maxX - pad - f.width }
        if f.minX < vis.minX + pad { f.origin.x = vis.minX + pad }
        if f.minY < vis.minY + pad { f.origin.y = vis.minY + pad }
        if f != win.frame { win.setFrame(f, display: true) }
    }

    func popoverDidClose(_ notification: Notification) {
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
            clickMonitor = nil
        }
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
