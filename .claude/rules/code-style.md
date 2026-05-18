# Code Style

- Follow the project's existing patterns and conventions
- Keep functions focused and small
- Prefer explicit over implicit
- Write self-documenting code — add comments only where logic isn't self-evident
- UI state lives in `QuarantineStore` (`@MainActor`, `@Observable`); views stay declarative.
- System calls (`xattr`, `spctl`, `codesign`, file enumeration) and all file-mutating actions are confined to the non-UI files (`DownloadsScanner`, `Signature`, `DownloadActions`).
- Scanning is strictly read-only. The only file-mutating actions live in `DownloadActions` and follow the same ethos as Sentry: every one is **user-initiated** (never automatic), fenced to `~/Downloads`, and reversible where possible — `defang`⇄`rearm` is a pure rename, "move to Trash" is recoverable. The single irreversible action (permanent delete) must be behind an explicit destructive confirmation in the UI and clearly flagged as unrecoverable.
- Network (VirusTotal) is strictly optional, async, and non-blocking; failures are swallowed.
