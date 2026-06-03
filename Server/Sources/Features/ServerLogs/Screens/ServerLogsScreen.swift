import SwiftUI

struct ServerLogsScreen: View {
    @StateObject private var viewModel: ServerLogsScreenViewModel

    init(feature: ServerLogsFeature) {
        _viewModel = StateObject(
            wrappedValue: ServerLogsScreenViewModel(
                service: feature.service,
                toolIconProvider: { feature.toolIcon(for: $0) }
            )
        )
    }

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: "Server Logs",
                    subtitle: "Structured local runtime history with newest-first indexed queries."
                ) {
                    HStack(spacing: 8) {
                        Button("Clear Logs", role: .destructive) {
                            viewModel.clearLogs()
                        }
                        .buttonStyle(.bordered)

                        DSRefreshButton(isLoading: viewModel.isLoading) {
                            viewModel.refresh()
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if viewModel.entries.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        title: "No structured logs yet",
                        message: "Run AI Connection to persist runtime milestones such as session start, completed outputs, tool results, and failures.",
                        systemImage: "terminal"
                    )
                } else {
                    NavigationSplitView {
                        ServerLogsTableView(viewModel: viewModel)
                            .navigationSplitViewColumnWidth(min: 620, ideal: 760)
                    } detail: {
                        if let selectedEntry = viewModel.selectedEntry {
                            ServerLogDetailView(
                                entry: selectedEntry,
                                toolIcon: viewModel.toolIcon(for: selectedEntry.toolName)
                            )
                        } else {
                            EmptyStateView(
                                title: "Select a log entry",
                                message: "Choose a row to inspect its structured payloads.",
                                systemImage: "list.bullet.rectangle"
                            )
                        }
                    }
                }
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
    }
}
