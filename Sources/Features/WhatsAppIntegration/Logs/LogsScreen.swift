import AppKit
import SwiftUI

struct LogsScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var didCopyLogs = false

    var body: some View {
        VStack(spacing: 0) {
            runtimeCard

            Divider()

            LogView(logs: appModel.logs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var runtimeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Runtime")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                runtimeChip(title: "Accessibility", isOn: appModel.accessibilityTrusted)
                runtimeChip(title: "WhatsApp", isOn: appModel.whatsappRunning)
            }

            Text(appModel.runtimeDescription)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button {
                    copyLogsToClipboard()
                    didCopyLogs = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        didCopyLogs = false
                    }
                } label: {
                    Label(didCopyLogs ? "Copied" : "Copy logs", systemImage: didCopyLogs ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copies all WhatsApp Integration logs to the clipboard.")

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                runtimeStatusPill(text: appModel.lastRefreshDescription, systemImage: "clock")
                runtimeStatusPill(text: appModel.isPolling ? "Polling active" : "Polling idle", systemImage: "dot.radiowaves.left.and.right")
                runtimeStatusPill(text: appModel.mcpServerStatusDescription, systemImage: "server.rack")

                if appModel.pendingClientAskCount > 0 {
                    runtimeStatusPill(text: "\(appModel.pendingClientAskCount) pending ask(s)", systemImage: "message")
                }

                Spacer(minLength: 0)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func copyLogsToClipboard() {
        let lines = appModel.logs.map { entry in
            let ts = entry.timestamp.formatted(date: .omitted, time: .standard)
            return "[\(ts)] [\(entry.level.rawValue.uppercased())] \(entry.message)"
        }
        let joined = lines.joined(separator: "\n")

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(joined, forType: .string)
    }

    private func runtimeChip(title: String, isOn: Bool) -> some View {
        Label(title, systemImage: isOn ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isOn ? .green : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isOn ? Color.green.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
            )
    }

    private func runtimeStatusPill(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
    }
}

#Preview {
    LogsScreen()
        .environmentObject(AppModel.preview)
        .frame(width: 980, height: 680)
}
