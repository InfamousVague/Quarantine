# Code Style

- Follow the project's existing patterns and conventions
- Keep functions focused and small
- Prefer explicit over implicit
- Write self-documenting code — add comments only where logic isn't self-evident
- UI state lives in `QuarantineStore` (`@MainActor`, `@Observable`); views stay declarative.
- System calls (`xattr`, `spctl`, `codesign`, file enumeration) are confined to the non-UI files.
- The app only inspects and reports — it never modifies, quarantines, or deletes a file.
- Network (VirusTotal) is strictly optional, async, and non-blocking; failures are swallowed.
