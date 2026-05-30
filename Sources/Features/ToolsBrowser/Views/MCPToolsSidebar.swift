import SwiftUI

struct MCPToolsSidebar: View {
    @ObservedObject var viewModel: MCPToolsBrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !viewModel.hasTools {
                EmptyStateView(
                    title: "No registered tools",
                    message: "Start the profile runtime features to populate the active MCP tool registry.",
                    systemImage: "hammer"
                )
            } else if viewModel.filteredEntries.isEmpty {
                EmptyStateView(
                    title: "No matching tools",
                    message: "Try a different search term or group filter.",
                    systemImage: "magnifyingglass"
                )
            } else {
                List(selection: $viewModel.selectedToolName) {
                    ForEach(viewModel.filteredEntries) { entry in
                        MCPToolRowView(entry: entry)
                            .tag(entry.name as String?)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .padding(16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MCP Tools")
                .font(.title3.weight(.semibold))

            TextField("Search tools", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)

            Picker("Group", selection: selectedGroupBinding) {
                Text("All").tag(nil as String?)
                ForEach(viewModel.groups, id: \.self) { group in
                    Text(group).tag(group as String?)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var selectedGroupBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedGroup },
            set: { viewModel.selectedGroup = $0 }
        )
    }
}
