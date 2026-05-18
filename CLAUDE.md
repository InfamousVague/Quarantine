# quarantine (native)

Native macOS menu-bar Downloads inspector. Watches `~/Downloads` and, for every
new file, surfaces its trust posture: the `com.apple.quarantine` agent + origin
URL, Gatekeeper/codesign status, SHA-256, and (optionally) a VirusTotal verdict.
Notifies on each new download; click the notification to jump to that file in
the popover. From the popover, per-item **user-initiated** actions: **Defang**
(rename to `…​.quarantine` so a double-click can't launch/mount it) and its
inverse **Re-arm**, **Reveal**, **Move to Trash** (recoverable), and a
hard-confirmed **Delete Permanently**. Scanning stays read-only; the actions are
the only mutations, never automatic. Swift + SwiftUI, `NSStatusItem` +
`NSPopover`, no third-party deps.

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
- `Sources/Quarantine/DownloadActions.swift` — the only file-mutating code:
  `defang`/`rearm`/`moveToTrash`/`deletePermanently`, each fenced to
  `~/Downloads`. User-initiated only; the UI confirms the destructive ones.
- `Sources/Quarantine/VirusTotal.swift` — optional `VT_API_KEY` lookup by hash
  (async, non-blocking, HTTPS — no ATS exception needed).
- `Sources/Quarantine/Notifier.swift` — `UNUserNotificationCenter` wrapper.
- `Sources/Quarantine/ContentView.swift` — the menu-bar popover UI (per-row
  actions menu + destructive confirmations + error strip).

## Icons

- `art/AppIcon-source.png` — Dock/Finder icon (glass biohazard).
  `scripts/make-app.sh` bakes it into `AppIcon.icns`.
- `Sources/Quarantine/Resources/MenuBarIcon.png` — white biohazard glyph, a
  template `NSStatusItem` image (macOS tints it for the bar). Also rendered in
  the popover header tinted with `Color.quarantineAccent`, à la Espresso/Alfred.
- SF Symbol `arrow.down.circle` is only a fallback if the bundled art is missing.

## Running

```
swift build
swift run                 # menu-bar item appears; no Dock icon
bash scripts/make-app.sh  # assembles Quarantine.app (LSUIElement), Developer ID signed
open Quarantine.app       # run the bundled menu-bar agent

# Optional VirusTotal:
VT_API_KEY=... swift run
```
