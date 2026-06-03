import SwiftUI

struct AIConnectionScreen: View {
    @StateObject private var viewModel: AIConnectionPlaygroundViewModel

    init(feature: AIConnectionFeature) {
        _viewModel = StateObject(
            wrappedValue: AIConnectionPlaygroundViewModel(feature: feature)
        )
    }

    var body: some View {
        FeatureScreenContainer {
            DSFeatureHeader(
                title: "AI Connection",
                subtitle: "Runtime inspector/controller for prompt, output, reasoning, tools, usage, and errors."
            ) {
                HStack(spacing: 8) {
                    Button("Load Tools") {
                        Task { await viewModel.loadTools() }
                    }
                    .disabled(viewModel.isLoadingTools)

                    Button("Start Run") {
                        viewModel.startJob()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStart)

                    Button("Cancel") {
                        viewModel.cancelRun()
                    }
                    .disabled(!viewModel.canCancel)

                    Button("Reset") {
                        viewModel.resetRun()
                    }
                    .disabled(!viewModel.canReset)

                    Button("Open Logs Folder") {
                        viewModel.openLogsFolder()
                    }
                }
            }

            ScrollView {
                AIConnectionRunInspectorView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTools()
            }
        }
    }
}
