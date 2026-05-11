import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationSplitView {
            List {
                Section("Bridge") {
                    Label("WhatsApp", systemImage: appModel.whatsappRunning ? "checkmark.circle.fill" : "xmark.circle")
                    Label("Accessibility", systemImage: appModel.accessibilityTrusted ? "checkmark.circle.fill" : "lock.trianglebadge.exclamationmark")
                }

                Section("Runtime") {
                    Text(appModel.runtimeDescription)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Assistant MCP")
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                LogView(logs: appModel.logs)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                appModel.refreshStatus()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Button {
                appModel.requestAccessibilityPermission()
            } label: {
                Label("Permission", systemImage: "lock.open")
            }

            Button {
                appModel.dumpWhatsAppSnapshot()
            } label: {
                Label("Dump WhatsApp", systemImage: "doc.text.magnifyingglass")
            }

            Spacer()
        }
        .padding(12)
    }
}
