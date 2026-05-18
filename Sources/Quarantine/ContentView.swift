import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(QuarantineStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 400, height: 560)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 6) {
                Image(nsImage: QuarantineApp.appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
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
                                onReveal: { store.revealInFinder(item) }
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
        HStack {
            Button {
                store.refresh()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            Spacer()
            if !store.vtConfigured {
                Text("Set VT_API_KEY to enable VirusTotal")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Button("Quit Quarantine") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct DownloadRow: View {
    let item: DownloadItem
    let vt: VirusTotal.Verdict?
    let vtConfigured: Bool
    let highlighted: Bool
    let onCopyHash: () -> Void
    let onReveal: () -> Void

    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: trustIcon)
                .font(.system(size: 13))
                .foregroundStyle(trustColor)
                .frame(width: 16)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    Text(sizeString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
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
        .background(highlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        .animation(.easeInOut(duration: 0.25), value: highlighted)
        .contentShape(Rectangle())
        .onTapGesture { onReveal() }
        .help("Click to reveal in Finder")
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
