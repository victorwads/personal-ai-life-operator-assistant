import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedScreen: SidebarScreen? = .conversations

    enum SidebarScreen: String, CaseIterable, Identifiable {
        case conversations
        case settings
        case logs
        case debug

        var id: String { rawValue }

        var title: String {
            switch self {
            case .conversations: "Conversations"
            case .settings: "Settings"
            case .logs: "Logs"
            case .debug: "Debug"
            }
        }

        var systemImage: String {
            switch self {
            case .conversations: "bubble.left.and.bubble.right"
            case .settings: "gearshape"
            case .logs: "list.bullet.rectangle"
            case .debug: "point.3.connected.trianglepath.dotted"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedScreen) {
                ForEach(SidebarScreen.allCases) { screen in
                    Label(screen.title, systemImage: screen.systemImage)
                        .tag(screen)
                }
            }
            .navigationTitle("Assistant MCP")
        } detail: {
            VStack(spacing: 0) {
                headerBar
                Divider()
                selectedDetailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var selectedDetailView: some View {
        Group {
            switch selectedScreen ?? .conversations {
            case .conversations:
                ConversationsScreen()
            case .settings:
                SettingsScreen(appModel: appModel)
                    .padding(12)
            case .logs:
                LogsScreen()
            case .debug:
                DebugTreeScreen()
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Text((selectedScreen ?? .conversations).title)
                .font(.title3.weight(.semibold))

            Spacer()

            StatusBadge(
                title: "WhatsApp \(appModel.whatsappRunning ? "Open" : "Closed")",
                isOnline: appModel.whatsappRunning,
                subtitle: nil,
                help: "Shows whether WhatsApp is currently running."
            )

            StatusBadge(
                title: "Accessibility \(appModel.accessibilityTrusted ? "OK" : "Missing")",
                isOnline: appModel.accessibilityTrusted,
                subtitle: nil,
                help: "Shows whether this app has Accessibility permission."
            )

            MCPServerStatusBadge(
                isRunning: appModel.mcpServerRunning,
                address: appModel.mcpServerAddress,
                statusDescription: appModel.mcpServerStatusDescription
            )

            Text(appModel.lastRefreshDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}
