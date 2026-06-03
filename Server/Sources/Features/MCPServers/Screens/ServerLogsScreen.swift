import SwiftUI

struct ServerLogsScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Server Logs",
            subtitle: "MCP server calls, runtime events, and diagnostic logs."
        ) {
            EmptyStateView(
                title: "Server logs workspace is not implemented yet",
                message: "MCP server calls, runtime events, and diagnostic logs will appear here.",
                systemImage: "terminal"
            )
        }
    }
}
