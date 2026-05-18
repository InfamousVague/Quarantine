# quarantine (native)

Native macOS menu-bar Downloads inspector. Watches `~/Downloads` and, for every
new file, surfaces its trust posture: the `com.apple.quarantine` agent + origin
URL, Gatekeeper/codesign status, SHA-256, and (optionally) a VirusTotal verdict.
Notifies on each new download; click the notification to jump to that file in
the popover. Swift + SwiftUI, `NSStatusItem` + `NSPopover`, no third-party deps.

## Commit Convention
Angular commits required with scope. See @.claude/rules/commit-rules.md for details.

## Code Style
See @.claude/rules/code-style.md

## Architecture

- `Sources/Quarantine/QuarantineApp.swift` — `@main` SwiftUI app: `NSStatusItem`
  + `NSPopover` via `AppDelegate`, `.accessory` activation (no Dock icon).
- `Sources/Quarantine/Models.swift` — `QuarantineStore` (`@Observable`,
  `@MainActor`): 5s Timer poll, detached scan, new-item diff + notify.
- `Sources/Quarantine/DownloadsScanner.swift` — enumerates `~/Downloads`,
  reads the `com.apple.quarantine` xattr, streams a CryptoKit SHA-256.
- `Sources/Quarantine/Signature.swift` — `spctl`/`codesign` Gatekeeper
  classification (notarized / signed / unsigned / n/a).
- `Sources/Quarantine/VirusTotal.swift` — optional `VT_API_KEY` lookup by hash
  (async, non-blocking, HTTPS — no ATS exception needed).
- `Sources/Quarantine/Notifier.swift` — `UNUserNotificationCenter` wrapper.
- `Sources/Quarantine/ContentView.swift` — the menu-bar popover UI.

## Menu-bar icon

SF Symbol `arrow.down.circle` rendered as a template `NSStatusItem` image
(macOS tints it for the active bar appearance). No bundled icon assets.

## Running

```
swift build
swift run                 # menu-bar item appears; no Dock icon
bash scripts/make-app.sh  # assembles Quarantine.app (LSUIElement), Developer ID signed
open Quarantine.app       # run the bundled menu-bar agent

# Optional VirusTotal:
VT_API_KEY=... swift run
```
