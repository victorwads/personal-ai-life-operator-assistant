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
            if isSuccess {
                if let renderedPayload = MCPToolsBrowserJSONFormatting.prettyPrintedSuccessPayload(
                    result.payload
                ) {
                    DSCodeBlock(renderedPayload)
                } else {
                    Text("This tool completed without returning a payload.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Label(
                    "Failed",
                    systemImage: "xmark.octagon.fill"
                )
                .foregroundStyle(.red)

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
}
