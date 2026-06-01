import SwiftUI

@MainActor
struct WhatsAppLogsScreen: View {
    let feature: WhatsAppCrawlingFeature
    @State private var autoScroll = true

    var body: some View {
        WhatsAppLogsContent(logStore: feature.logStore, autoScroll: $autoScroll)
    }
}

@MainActor
private struct WhatsAppLogsContent: View {
    @ObservedObject var logStore: WhatsAppCrawlingLogStore
    @Binding var autoScroll: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DSFeatureHeader(title: "WhatsApp Logs") {
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Button("Clear") {
                    logStore.clear()
                }
            }

            ScrollViewReader { proxy in
                List(logStore.entries) { entry in
                    Text(line(for: entry))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .id(entry.id)
                }
                .onChange(of: logStore.entries.count) { _ in
                    guard autoScroll, let last = logStore.entries.last else { return }
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .dsFeatureHeaderContentInsets(DSFeatureHeaderContentInsets.none)
        .padding()
    }

    private func line(for entry: WhatsAppCrawlingLogEntry) -> String {
        let time = Self.timeFormatter.string(from: entry.date)
        return "\(time)  \(entry.source.padding(toLength: 12, withPad: " ", startingAt: 0))  \(entry.message)"
    }
}
