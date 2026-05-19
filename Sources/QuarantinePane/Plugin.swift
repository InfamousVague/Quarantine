import AppKit
import SwiftUI
import SuiteKit

/// Quarantine as a SuiteKit pane. Owns the store, vends the UI +
/// glyph, routes a tapped notification to the offending download.
@MainActor
public final class QuarantinePaneProvider: NSObject, SuitePane {
    private let store = QuarantineStore()

    public var suiteABIVersion: Int { SuiteKitABI.current }
    public var paneID: String { "quarantine" }
    public var paneTitle: String { "QUARANTINE" }
    public var paneTintHex: String { "#33C9EB" }

    public func paneMenuBarImage() -> NSImage {
        QuarantineBrand.menuBarIcon
    }

    public func paneMakeView() -> NSView {
        NSHostingView(rootView: ContentView().environment(store))
    }

    public func paneStart() {
        store.start()
        Notifier.requestAuthorization()
    }

    public func paneStop() {
        // 5s downloads poll is harmless to leave running.
    }

    public func paneFocus(_ key: String) {
        store.focusedKey = key
    }
}

@_cdecl("suitePaneCreate")
public func suitePaneCreate() -> Unmanaged<AnyObject> {
    MainActor.assumeIsolated {
        Unmanaged.passRetained(QuarantinePaneProvider())
    }
}
