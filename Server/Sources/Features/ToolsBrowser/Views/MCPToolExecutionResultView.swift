import SwiftUI

struct MCPToolExecutionResultView: View {
    let state: MCPToolExecutionState

    var body: some View {
        MCPToolSectionCard(title: "Execution Result") {
            switch state {
            case .idle:
                Label("Run the selected tool to see its result.", systemImage: "play.circle")
                    .foregroundStyle(.secondary)
            case .running:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Executing tool...")
                        .foregroundStyle(.secondary)
                }
            case let .success(result):
                resultContent(result, isSuccess: true)
            case let .failure(result):
                resultContent(result, isSuccess: false)
            }
        }
    }

    private func resultContent(_ result: MCPToolExecutionResult, isSuccess: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                isSuccess ? "Success" : "Failed",
                systemImage: isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill"
            )
            .foregroundStyle(isSuccess ? .green : .red)

            if let duration = result.durationMilliseconds {
                Text("\(duration, specifier: "%.1f") ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Result JSON")
                .font(.subheadline.weight(.semibold))
            DSCodeBlock(MCPToolsBrowserJSONFormatting.prettyPrinted(result: result))
        }
    }
}
