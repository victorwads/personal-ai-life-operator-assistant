import SwiftUI

struct AIConnectionRunInspectorView: View {
    @ObservedObject var viewModel: AIConnectionPlaygroundViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AIRunHeaderView(viewModel: viewModel)
            AIRunUsagePanelView(usage: viewModel.usageState)
            AIRunPromptPanelView(promptState: viewModel.promptState)
            AIRunTextOutputPanelView(text: viewModel.assistantText)
            AIRunReasoningPanelView(text: viewModel.reasoningText)
            AIToolDefinitionsPanelView(tools: viewModel.tools)
            AIToolCallTimelineView(toolCalls: viewModel.toolCalls)
            AIRunDebugPanelView(debugEvents: viewModel.debugEvents)
        }
    }
}

struct AIRunHeaderView: View {
    @ObservedObject var viewModel: AIConnectionPlaygroundViewModel

    var body: some View {
        DSTitledSection(
            title: "Run",
            subtitle: "Aggregated execution inspector for prompt, outputs, tool calls, usage, and errors.",
            systemImage: "play.circle"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("User prompt", text: $viewModel.prompt)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                HStack(spacing: 10) {
                    Button("Load Tools") {
                        Task { await viewModel.loadTools() }
                    }
                    .disabled(viewModel.isLoadingTools || viewModel.isStreaming)

                    Button("Start Run") {
                        viewModel.startJob()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isStreaming)

                    Button("Cancel") {
                        viewModel.cancelRun()
                    }
                    .disabled(!viewModel.isStreaming)

                    Button("Clear") {
                        viewModel.clear()
                    }
                    .disabled(viewModel.isStreaming)
                }

                HStack(spacing: 8) {
                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DSBadge(viewModel.runStatus.rawValue.capitalized, style: badgeStyle)
                }

                if let providerError = viewModel.providerError {
                    Text(providerError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var badgeStyle: DSBadge.Style {
        switch viewModel.runStatus {
        case .idle:
            return .neutral
        case .running:
            return .info
        case .completed:
            return .success
        case .failed, .cancelled:
            return .danger
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
            VStack(alignment: .leading, spacing: 10) {
                DisclosureGroup("System Prompt") {
                    DSCodeBlock(promptState.systemPrompt)
                        .frame(maxHeight: 180)
                }

                DisclosureGroup("User Prompt") {
                    DSCodeBlock(promptState.userPrompt.isEmpty ? "No run started yet." : promptState.userPrompt)
                        .frame(maxHeight: 140)
                }
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

    var body: some View {
        DSTitledSection(
            title: "Tool Definitions",
            subtitle: "Available MCP tools from AI Connection feature context.",
            systemImage: "wrench.and.screwdriver"
        ) {
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
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tool call id")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(call.id)
                        .font(.caption.monospaced())
                }

                DSCodableDebugInspector(title: "Tool call details", value: call)
            }
            .padding(.top, 6)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: call.icon ?? "hammer")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(call.name)
                            .font(.subheadline.weight(.semibold))
                        DSBadge(call.status.rawValue, style: statusStyle)
                    }

                    Text(call.argumentsPreview)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .foregroundStyle(.secondary)

                    Text("start: \(date(call.startedAt))  end: \(date(call.endedAt))  duration: \(call.durationText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var statusStyle: DSBadge.Style {
        switch call.status {
        case .started, .argumentsStreaming:
            return .info
        case .argumentsReady:
            return .warning
        case .completed:
            return .success
        case .failed, .cancelled:
            return .danger
        }
    }

    private func date(_ value: Date?) -> String {
        guard let value else { return "-" }
        return Self.timeFormatter.string(from: value)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

struct AIRunDebugPanelView: View {
    let debugEvents: [AIRunDebugEventState]
    @State private var isExpanded = false

    var body: some View {
        DSTitledSection(
            title: "Debug",
            subtitle: "Collapsed, capped internal stream events.",
            systemImage: "ladybug"
        ) {
            DisclosureGroup("Raw/debug events (\(debugEvents.count))", isExpanded: $isExpanded) {
                DSCodeBlock(
                    debugEvents.isEmpty
                        ? "No debug events"
                        : debugEvents.map(\.line).joined(separator: "\n")
                )
                .frame(minHeight: 80, maxHeight: 180)
            }
        }
    }
}
