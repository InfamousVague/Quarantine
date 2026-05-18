import SwiftUI
import AppKit

/// Quarantine's brand accent — the cyan chromatic rim of the glass
/// biohazard icon, brightened so it reads as a confident tint on the
/// dark popover rather than mud. Mirrors the Espresso/Alfred pattern
/// (a named accent + a darker companion).
extension Color {
    static let quarantineAccent = Color(red: 0.202, green: 0.789, blue: 0.920)
    static let quarantineAccentDark = Color(red: 0.160, green: 0.372, blue: 0.420)
}

struct ContentView: View {
    @Environment(QuarantineStore.self) private var store
    @State private var showVTSetup = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let err = store.lastError {
                errorStrip(err)
                Divider()
            }
            list
            Divider()
            footer
        }
        .frame(width: 400, height: 560)
        .glassScrollers()
        // Brand-tint controls + `.tint` foregrounds panel-wide, the
        // way Espresso/Alfred apply their accent across the popover.
        .tint(.quarantineAccent)
        .sheet(isPresented: $showVTSetup) {
            VTKeySheet(store: store) { showVTSetup = false }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 6) {
                // The tray glyph itself, tinted in the brand accent —
                // exactly how Espresso/Alfred show their glyph in the
                // panel header (vs. the full-colour app icon).
                Image(nsImage: QuarantineApp.trayGlyph)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Color.quarantineAccent)
                Text("QUARANTINE")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(2)
                LiveDot()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("~/Downloads")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("\(store.items.count) item\(store.items.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func errorStrip(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .lineLimit(2)
            Spacer(minLength: 4)
            Button {
                store.lastError = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(Color.red)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.12))
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if store.items.isEmpty {
                    Text("No downloads found.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                            DownloadRow(
                                item: item,
                                vt: store.vtVerdicts[item.sha256],
                                vtConfigured: store.vtConfigured,
                                highlighted: store.focusedKey == item.path,
                                onCopyHash: { store.copyHash(item) },
                                onReveal: { store.revealInFinder(item) },
                                onDefang: { store.defang(item) },
                                onRearm: { store.rearm(item) },
                                onTrash: { store.moveToTrash(item) },
                                onDeletePermanently: { store.deletePermanently(item) }
                            )
                            .id(item.path)
                            if index < store.items.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .onChange(of: store.focusedKey) { _, key in
                guard let key else { return }
                withAnimation { proxy.scrollTo(key, anchor: .center) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if store.focusedKey == key { store.focusedKey = nil }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .controlSize(.small)
            .help("Rescan")
            Button {
                showVTSetup = true
            } label: {
                Image(systemName: store.vtConfigured
                    ? "checkmark.shield.fill" : "key.fill")
            }
            .controlSize(.small)
            .tint(store.vtConfigured ? Color.green : Color.quarantineAccent)
            .help(store.vtConfigured
                ? "VirusTotal on — change API key"
                : "Enable VirusTotal (set API key)")
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .controlSize(.small)
            .help("Quit Quarantine")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

private struct DownloadRow: View {
    let item: DownloadItem
    let vt: VirusTotal.Verdict?
    let vtConfigured: Bool
    let highlighted: Bool
    let onCopyHash: () -> Void
    let onReveal: () -> Void
    let onDefang: () -> Void
    let onRearm: () -> Void
    let onTrash: () -> Void
    let onDeletePermanently: () -> Void

    @State private var copied = false
    @State private var confirmingTrash = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: trustIcon)
                .font(.system(size: 13))
                .foregroundStyle(trustColor)
                .frame(width: 16)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    Text(sizeString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    actionsMenu
                }

                HStack(spacing: 6) {
                    if item.isDefanged {
                        Text("DEFANGED")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.18))
                            .foregroundStyle(Color.orange)
                            .clipShape(Capsule())
                    }
                    Text(item.trustSummary)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(trustColor.opacity(0.15))
                        .foregroundStyle(trustColor)
                        .clipShape(Capsule())
                    Text(item.typeDescription)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let vt {
                        Text(vt.flagged
                             ? "VT \(vt.malicious + vt.suspicious) flagged"
                             : "VT clean")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background((vt.flagged ? Color.red : Color.green).opacity(0.15))
                            .foregroundStyle(vt.flagged ? Color.red : Color.green)
                            .clipShape(Capsule())
                    }
                }

                if let origin = item.originURL {
                    Text(origin)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let agent = item.quarantineAgent {
                    Text("via \(agent)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                } else {
                    Text("no quarantine record")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Text(item.shortHash + "…")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button {
                        onCopyHash()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Copy full SHA-256")
                    if let team = item.teamID {
                        Text("Team \(team)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(highlighted ? Color.quarantineAccent.opacity(0.18) : Color.clear)
        .animation(.easeInOut(duration: 0.25), value: highlighted)
        .contentShape(Rectangle())
        .onTapGesture { onReveal() }
        .help("Click to reveal in Finder")
        .confirmationDialog(
            "Move “\(item.displayName)” to the Trash?",
            isPresented: $confirmingTrash, titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { onTrash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can restore it from the Trash later.")
        }
        .confirmationDialog(
            "Delete “\(item.displayName)” permanently?",
            isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) { onDeletePermanently() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone — the file is NOT moved to the Trash.")
        }
    }

    @ViewBuilder private var actionsMenu: some View {
        Menu {
            if item.isDefanged {
                Button(action: onRearm) {
                    Label("Re-arm (restore name)", systemImage: "arrow.uturn.left")
                }
            } else {
                Button(action: onDefang) {
                    Label("Defang (rename to .quarantine)",
                          systemImage: "exclamationmark.shield")
                }
            }
            Button(action: onReveal) {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }
            Button(action: onCopyHash) {
                Label("Copy SHA-256", systemImage: "number")
            }
            Divider()
            Button(role: .destructive) { confirmingTrash = true } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            Button(role: .destructive) { confirmingDelete = true } label: {
                Label("Delete Permanently…", systemImage: "trash.slash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Actions")
    }

    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
    }

    private var trustColor: Color {
        switch item.trust {
        case .notarized:      return .green
        case .signed:         return .yellow
        case .unsigned:       return .red
        case .notApplicable:  return .secondary
        case .unknown:        return .secondary
        }
    }

    private var trustIcon: String {
        switch item.trust {
        case .notarized:      return "checkmark.seal.fill"
        case .signed:         return "exclamationmark.shield.fill"
        case .unsigned:       return "xmark.shield.fill"
        case .notApplicable:  return "doc"
        case .unknown:        return "questionmark.circle"
        }
    }
}

private struct VTKeySheet: View {
    let store: QuarantineStore
    let onClose: () -> Void

    private enum Status { case idle, valid, invalid }

    @State private var keyText = ""
    @State private var status: Status = .idle
    @State private var validating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VirusTotal API key")
                .font(.system(size: 14, weight: .semibold))

            if store.vtEnvManaged {
                Text("The key is currently set by the VT_API_KEY environment variable, which overrides this. Unset it to manage the key here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Paste a free VirusTotal API key to enrich downloads with a malware verdict. It's stored in your Keychain — no environment variable needed.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("VirusTotal API key", text: $keyText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: keyText) { _, _ in status = .idle }

                HStack(spacing: 8) {
                    Link("Get a free key →",
                         destination: URL(string: "https://www.virustotal.com/gui/my-apikey")!)
                        .font(.system(size: 11))
                    Spacer()
                    if validating {
                        ProgressView().controlSize(.small)
                    } else if status == .valid {
                        Label("Valid", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.system(size: 11))
                    } else if status == .invalid {
                        Label("Invalid key", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red).font(.system(size: 11))
                    }
                }
            }

            HStack {
                if !store.vtEnvManaged && !store.currentVTKey().isEmpty {
                    Button("Remove", role: .destructive) {
                        store.clearVTKey()
                        onClose()
                    }
                }
                Spacer()
                Button("Cancel", action: onClose)
                if !store.vtEnvManaged {
                    Button("Validate") {
                        Task {
                            validating = true
                            status = (await store.validateVTKey(trimmed)) ? .valid : .invalid
                            validating = false
                        }
                    }
                    .disabled(trimmed.isEmpty || validating)
                    Button("Save") {
                        store.saveVTKey(trimmed)
                        onClose()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
                }
            }
        }
        .padding(18)
        .frame(width: 380)
        .tint(.quarantineAccent)
        .onAppear { keyText = store.currentVTKey() }
    }

    private var trimmed: String {
        keyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct LiveDot: View {
    @State private var on = false

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
            .opacity(on ? 1 : 0.25)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
            .help("Live — rescanning every 5 seconds")
    }
}
