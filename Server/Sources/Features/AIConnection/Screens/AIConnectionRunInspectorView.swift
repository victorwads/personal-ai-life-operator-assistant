import SwiftUI

struct AIConnectionRunInspectorView: View {
    @ObservedObject var viewModel: AIConnectionPlaygroundViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                AIRunHeaderView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                AIRunUsagePanelView(usage: viewModel.runtimeState.usage)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            HStack(alignment: .top, spacing: 16) {
                AIRunTextOutputPanelView(text: viewModel.runtimeState.assistantText)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                AIRunReasoningPanelView(text: viewModel.runtimeState.reasoningText)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            AIToolCallTimelineView(toolCalls: viewModel.runtimeState.toolCalls)
            AIToolDefinitionsPanelView(tools: viewModel.runtimeState.availableToolDefinitions)
            AIRunDebugPanelView(debugEvents: viewModel.runtimeState.debugEvents)
            AIRunPromptPanelView(promptState: viewModel.promptState)
        }
    }
}

struct AIRunHeaderView: View {
    @ObservedObject var viewModel: AIConnectionPlaygroundViewModel

    var body: some View {
        DSTitledSection(
            title: "Run",
            subtitle: "Runtime-owned execution inspector for prompt, outputs, tool calls, usage, and errors.",
            systemImage: "play.circle"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("User prompt", text: $viewModel.prompt)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                HStack(spacing: 8) {
                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AIRuntimeStatusBadge(status: viewModel.runtimeState.status)
                }

                if let error = viewModel.runtimeState.errors.last {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

private struct AIRuntimeStatusBadge: View {
    let status: AIConnectionRuntimeStatus

    var body: some View {
        Label(status.displayName, systemImage: status.icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.color, in: Capsule())
    }
}

private extension AIConnectionRuntimeStatus {
    var color: Color {
        switch self {
        case .stopped, .cancelled:
            return .gray
        case .initializing, .promptProcessing:
            return .blue
        case .reasoning:
            return .purple
        case .executingTool, .waitingEvent, .paused:
            return .orange
        case .receivingOutput, .completed:
            return .green
        case .waitingUser:
            return .yellow.opacity(0.85)
        case .failed:
            return .red
        }
    }
}

struct AIRunUsagePanelView: View {
    let usage: AIRunUsageState

    var body: some View {
        DSTitledSection(
            title: "Usage",
            subtitle: "Input/output/reasoning tokens, TTPS, TTFT, and run duration.",
            systemImage: "speedometer"
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                usageRow("Input tokens", value: number(usage.inputTokens))
                usageRow("Output tokens", value: outputText)
                usageRow("Reasoning tokens", value: number(usage.reasoningTokens))
                usageRow("Total tokens", value: number(usage.totalTokens))
                usageRow("TTPS", value: rate(usage.tokensPerSecond))
                usageRow("Time to first token", value: time(usage.timeToFirstToken))
                usageRow("Run duration", value: time(usage.runDuration))
            }
        }
    }

    private var outputText: String {
        let base = number(usage.outputTokens)
        return usage.isOutputTokensEstimated ? "\(base) (estimated)" : base
    }

    private func usageRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    private func number(_ value: Int?) -> String {
        guard let value else { return "-" }
        return "\(value)"
    }

    private func rate(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f tok/s", value)
    }

    private func time(_ value: TimeInterval?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2fs", value)
    }
}

struct AIRunPromptPanelView: View {
    let promptState: AIRunPromptState

    var body: some View {
        DSTitledSection(
            title: "Prompts",
            subtitle: "Exact system and user prompts sent in the current run.",
            systemImage: "text.append"
        ) {
            HStack(alignment: .center, spacing: 10) {
                Text("Inspect exact prompt payloads with preserved raw formatting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                DSDebugObjectsInspector(
                    title: "Prompts",
                    items: [
                        DebugObjectItem(title: "System Prompt", value: promptState.systemPrompt),
                        DebugObjectItem(
                            title: "User Prompt",
                            value: promptState.userPrompt.isEmpty ? "No run started yet." : promptState.userPrompt
                        )
                    ]
                )

                Spacer(minLength: 0)
            }
        }
    }
}

struct AIRunTextOutputPanelView: View {
    let text: String

    var body: some View {
        DSTitledSection(
            title: "Assistant Output",
            subtitle: "Aggregated assistant text from streamed deltas.",
            systemImage: "text.bubble"
        ) {
            DSCodeBlock(text.isEmpty ? "No assistant text yet." : text)
                .frame(minHeight: 120, maxHeight: 260)
        }
    }
}

struct AIRunReasoningPanelView: View {
    let text: String

    var body: some View {
        DSTitledSection(
            title: "Reasoning Output",
            subtitle: "Aggregated reasoning deltas when the provider exposes reasoning.",
            systemImage: "brain.head.profile"
        ) {
            DSCodeBlock(text.isEmpty ? "No reasoning deltas provided by this run." : text)
                .frame(minHeight: 100, maxHeight: 220)
        }
    }
}

struct AIToolDefinitionsPanelView: View {
    let tools: [AIToolDefinition]
    @State private var isExpanded = false

    var body: some View {
        DSTitledSection(
            title: "Tool Definitions",
            subtitle: "Available MCP tools from AI Connection runtime cache.",
            systemImage: "wrench.and.screwdriver"
        ) {
            DisclosureGroup("Available tools (\(tools.count))", isExpanded: $isExpanded) {
                if tools.isEmpty {
                    Text("No tool definitions loaded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(tools, id: \.name) { tool in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: tool.icon ?? "hammer")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tool.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(tool.description.isEmpty ? "No description" : tool.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AIToolCallTimelineView: View {
    let toolCalls: [AIRunToolCallState]

    var body: some View {
        DSTitledSection(
            title: "Tool Calls",
            subtitle: "One row per tool call, updated in place while streaming.",
            systemImage: "timeline.selection"
        ) {
            if toolCalls.isEmpty {
                Text("No tool calls detected yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(toolCalls) { call in
                        AIToolCallTimelineRowView(call: call)
                    }
                }
            }
        }
    }
}

struct AIToolCallTimelineRowView: View {
    let call: AIRunToolCallState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: call.icon ?? "hammer")
                .foregroundStyle(.secondary)

            Text(call.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            DSBadge(call.status.rawValue, style: statusStyle)

            Text(call.durationText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("io:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DSDebugObjectsInspector(
                    title: "Tool Call",
                    items: [
                        DebugObjectItem(title: "Arguments", value: call.argumentsJSON),
                        DebugObjectItem(title: "Response", value: call.responseText ?? "")
                    ]
                )
            }

            Spacer(minLength: 0)

            Text(call.id)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private var statusStyle: DSBadge.Style {
        switch call.status {
        case .started, .argumentsStreaming, .executing:
            return .info
        case .argumentsReady:
            return .warning
        case .completed:
            return .success
        case .failed, .cancelled:
            return .danger
        }
    }
}

struct AIRunDebugPanelView: View {
    let debugEvents: [AIRunDebugEventState]

    var body: some View {
        DSTitledSection(
            title: "Debug",
            subtitle: "Collapsed, capped internal stream events.",
            systemImage: "ladybug"
        ) {
            HStack(alignment: .center, spacing: 10) {
                Text("Inspect the captured runtime event stream in one shared debug viewer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                DSDebugObjectsInspector(
                    title: "Runtime Event",
                    items: [
                        DebugObjectItem(
                            title: "Raw Payload",
                            value: debugEvents.isEmpty
                                ? "No debug events"
                                : debugEvents.map(\.line).joined(separator: "\n")
                        ),
                        DebugObjectItem(title: "Parsed Payload", value: debugEvents)
                    ]
                )

                Spacer(minLength: 0)
            }
        }
    }
}
