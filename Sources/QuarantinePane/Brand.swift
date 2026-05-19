import AppKit
import ObjectiveC

/// Quarantine's glyphs + resource resolver, relocated out of the
/// thin `Quarantine` shim so the pane (what the launcher loads) and
/// the standalone app share one source. Does NOT use SwiftPM's
/// `Bundle.module` (it `fatalError`s when a dlopen'd pane can't find
/// its bundle); resolves safely with an SF Symbol fallback instead.
enum QuarantineBrand {
    private final class BundleToken {}

    static func resourceURL(_ name: String, _ ext: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: ext) {
            return u
        }
        // `Bundle(for:)` is unreliable for a dlopen'd loose dylib (it
        // returns the host launcher's main bundle), so ask the
        // dynamic linker for this class's real image path.
        if let img = class_getImageName(BundleToken.self) {
            let dylib = URL(fileURLWithPath: String(cString: img))
            let fw = dylib.deletingLastPathComponent()
            if let b = Bundle(url: fw.appendingPathComponent(
                    "Quarantine_QuarantinePane.bundle")),
               let u = b.url(forResource: name, withExtension: ext) {
                return u
            }
            let res = fw.deletingLastPathComponent()
                .appendingPathComponent("Resources/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: res.path) {
                return res
            }
            let same = fw.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: same.path) {
                return same
            }
        }
        return Bundle(for: BundleToken.self)
            .url(forResource: name, withExtension: ext)
    }

    /// Status-bar glyph: the macOS download symbol (vector, crisp).
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

    /// Panel-header glyph (tinted by the accent), prefers bundled art.
    static let trayGlyph: NSImage = {
        let image: NSImage
        if let url = resourceURL("MenuBarIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = NSImage(
                systemSymbolName: "arrow.down.circle",
                accessibilityDescription: "Quarantine") ?? NSImage()
        }
        image.isTemplate = true
        return image
    }()

    /// Full-colour app icon for in-app branding.
    static let appIcon: NSImage = {
        if let url = resourceURL("AppIcon", "png"),
           let loaded = NSImage(contentsOf: url) {
            return loaded
        }
        return NSImage(systemSymbolName: "arrow.down.circle.fill",
                       accessibilityDescription: "Quarantine")
            ?? NSImage()
    }()
}
