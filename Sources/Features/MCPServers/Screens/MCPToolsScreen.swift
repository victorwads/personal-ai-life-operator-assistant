import SwiftUI

struct MCPToolsScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Tools",
            subtitle: "MCP tool definitions, availability, and execution inspection."
        ) {
            EmptyStateView(
                title: "MCP tools workspace is not implemented yet",
                message: "MCP tool definitions, availability, and execution inspection will appear here.",
                systemImage: "hammer"
            )
        }
    }
}
