import SwiftUI

struct MCPToolsScreen: View {
    @StateObject private var viewModel: MCPToolsBrowserViewModel

    init(mcpServersFeature: MCPServersFeature) {
        _viewModel = StateObject(
            wrappedValue: MCPToolsBrowserViewModel(mcpServersFeature: mcpServersFeature)
        )
    }

    var body: some View {
        NavigationSplitView {
            MCPToolsSidebar(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            MCPToolDetailView(viewModel: viewModel)
        }
        .navigationTitle("MCP Tools")
    }
}
