import SwiftUI

struct AIConnectionScreen: View {
    @StateObject private var viewModel: AIConnectionPlaygroundViewModel

    init(feature: AIConnectionFeature) {
        _viewModel = StateObject(
            wrappedValue: AIConnectionPlaygroundViewModel(feature: feature)
        )
    }

    var body: some View {
        FeatureScreenContainer(
            title: "AI Connection",
            subtitle: "Aggregated AI run inspector for prompts, output, reasoning, tools, usage, and errors."
        ) {
            ScrollView {
                AIConnectionRunInspectorView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTools()
            }
        }
    }
}
