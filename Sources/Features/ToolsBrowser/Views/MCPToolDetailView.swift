import SwiftUI

struct MCPToolDetailView: View {
    @ObservedObject var viewModel: MCPToolsBrowserViewModel

    var body: some View {
        Group {
            if let tool = viewModel.selectedTool {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MCPToolMetadataView(tool: tool)

                        MCPToolCodeSection(
                            title: "Input Schema",
                            code: MCPToolsBrowserJSONFormatting.prettyPrinted(tool.inputSchema)
                        )

                        MCPToolExamplesView(examples: viewModel.selectedToolExamples)

                        MCPToolArgumentsEditor(
                            examples: viewModel.selectedToolExamples,
                            argumentDrafts: $viewModel.argumentDrafts
                        )

                        MCPToolPayloadPreview(payload: viewModel.payloadPreview)

                        actions

                        MCPToolExecutionResultView(state: viewModel.executionState)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                EmptyStateView(
                    title: "No tool selected",
                    message: "Choose a registered MCP tool to inspect its metadata and execute it.",
                    systemImage: "hammer"
                )
            }
        }
    }

    private var actions: some View {
        HStack {
            Button {
                Task { await viewModel.runSelectedTool() }
            } label: {
                Label("Run Tool", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.executionState == .running)

            Button {
                viewModel.resetArgumentsFromSelectedToolExamples()
            } label: {
                Label("Reset Arguments", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)

            if viewModel.executionState == .running {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

private struct MCPToolExamplesView: View {
    let examples: [MCPToolExampleParameter]

    var body: some View {
        MCPToolSectionCard(title: "Example Parameters") {
            if examples.isEmpty {
                Text("This tool does not provide example parameters.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(examples, id: \.name) { example in
                        DSCard(title: example.name) {
                            if let note = example.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            DSCodeBlock(MCPToolsBrowserJSONFormatting.prettyPrinted(example.value))
                        }
                    }
                }
            }
        }
    }
}
