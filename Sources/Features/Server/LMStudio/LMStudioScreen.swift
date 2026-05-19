import Foundation
import SwiftUI

struct LMStudioScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var lmStudio: LMStudioSessionManager
    private let mcpServerURL: URL?
    private let preferredModelDisplayName = "Qwen3.6 35B A3B"
    @State private var selectedTimelineFilter: TimelineFilter = .important
    @State private var showDeltaEvents = false
    @State private var showDebugEvents = false

    enum TimelineFilter: String, CaseIterable, Identifiable {
        case important = "Important"
        case chat = "Chat"
        case model = "Model"
        case prompt = "Prompt"
        case reasoning = "Reasoning"
        case tool = "Tool"
        case message = "Message"
        case error = "Error"
        case all = "All"

        var id: String { rawValue }
    }

    init(lmStudio: LMStudioSessionManager, mcpServerURL: URL?) {
        self.lmStudio = lmStudio
        self.mcpServerURL = mcpServerURL
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.12, blue: 0.16),
                            Color(red: 0.10, green: 0.18, blue: 0.20),
                            Color(red: 0.16, green: 0.22, blue: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Divider()

            HSplitView {
                leftPane
                    .frame(minWidth: 360, idealWidth: 420, maxWidth: 560)

                rightPane
                    .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if lmStudio.models.isEmpty {
                await lmStudio.refreshModels()
            }
            selectPreferredModelIfNeeded()
        }
        .onChange(of: lmStudio.models) { _, _ in
            selectPreferredModelIfNeeded()
        }
    }

    private var banner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LM Studio")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Start, pause, and restart the assistant session that drives the operational loop.")
                        .foregroundStyle(.white.opacity(0.78))
                        .font(.callout)

                    HStack(spacing: 10) {
                        chip(
                            title: lmStudio.statusTitle,
                            detail: lmStudio.statusDetail,
                            icon: lmStudio.statusSymbolName,
                            color: statusColor
                        )

                        chip(
                            title: lmStudio.selectedModelLabel,
                            detail: lmStudio.selectedModelSubtitle,
                            icon: "cpu",
                            color: .teal
                        )

                        chip(
                            title: lmStudio.activeResponseID ?? "No response yet",
                            detail: "response_id",
                            icon: "number.circle",
                            color: .orange
                        )
                    }
                    .padding(.top, 2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            Task { await lmStudio.refreshModels() }
                        } label: {
                            Label("Refresh Models", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.18))

                        Menu {
                            if lmStudio.models.isEmpty {
                                Text("No models returned")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(lmStudio.models) { model in
                                    Button {
                                        lmStudio.selectedModelKey = model.key
                                    } label: {
                                        Text(model.displayName)
                                    }
                                }
                            }
                        } label: {
                            Label(selectedModelMenuLabel, systemImage: "cpu")
                                .lineLimit(1)
                        }
                        .menuStyle(.borderedButton)

                        Button {
                            Task { await startFreshSession() }
                        } label: {
                            Label("Start Fresh", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(mcpServerURL == nil || !appModel.mcpServerRunning)

                        Button {
                            Task { await lmStudio.pauseSession() }
                        } label: {
                            Label("Pause Session", systemImage: "pause.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.18))
                        .disabled(!lmStudio.isSessionActive)
                    }

                    Text("Start always clears the previous context. Pause only stops the current stream.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            HStack(spacing: 12) {
                smallLabel("MCP bridge", value: appModel.mcpServerRunning ? appModel.mcpServerStatusDescription : "Stopped", color: appModel.mcpServerRunning ? .green : .orange)
                smallLabel("Prompt source", value: lmStudio.promptSourceDescription, color: .blue)
                smallLabel("API", value: lmStudio.apiBaseURLText, color: .teal)
            }
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            sessionOverviewCard
            liveOutputCard

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    requirementsCard
                    connectionCard

                    if let error = lmStudio.lastErrorMessage, !error.isEmpty {
                        card(title: "Last Error", subtitle: "Most recent LM Studio or transport failure") {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            eventTimelineCard
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sessionOverviewCard: some View {
        card(title: "Session Overview", subtitle: "Current state, model instance, and response identity") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    infoPill("State", value: lmStudio.statusTitle, color: statusColor)
                    infoPill("Response ID", value: lmStudio.activeResponseID ?? "—", color: .orange)
                    infoPill("Model instance", value: lmStudio.activeModelInstanceID ?? "—", color: .teal)
                }

                Text(lmStudio.statusDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var liveOutputCard: some View {
        card(title: "Live Output", subtitle: "Reasoning and message streams from the active session") {
            VStack(alignment: .leading, spacing: 14) {
                outputBlock(
                    title: "Reasoning",
                    text: lmStudio.liveReasoningText,
                    tint: .secondary
                )

                outputBlock(
                    title: "Assistant message",
                    text: lmStudio.latestOutputText,
                    tint: .blue
                )
            }
        }
    }

    private var requirementsCard: some View {
        card(title: "LM Studio Requirements", subtitle: "Two server toggles can affect what you see") {
            VStack(alignment: .leading, spacing: 8) {
                Text("If LM Studio requires authentication, keep the API token filled in here.")
                Text("If you want tool calls from the per-request MCP bridge, enable `Allow per-request MCPs` in LM Studio Server Settings.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var connectionCard: some View {
        card(title: "Connection", subtitle: "LM Studio REST endpoint and optional auth token") {
            VStack(alignment: .leading, spacing: 12) {
                fieldRow(title: "API URL") {
                    TextField("http://localhost:1234", text: $lmStudio.apiBaseURLText)
                        .textFieldStyle(.roundedBorder)
                }

                fieldRow(title: "API token") {
                    SecureField("Optional", text: $lmStudio.apiToken)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Auto-run (start on server ready, restart on chat end)", isOn: $lmStudio.autoRunEnabled)
                    .toggleStyle(.switch)

                HStack(spacing: 10) {
                    Button {
                        openLMStudioApp()
                    } label: {
                        Label("Open LM Studio", systemImage: "app")
                    }
                    .buttonStyle(.bordered)

                    if let mcpServerURL {
                        Text("MCP bridge: \(mcpServerURL.absoluteString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("MCP bridge URL is unavailable.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var eventTimelineCard: some View {
        card(title: "Event Timeline", subtitle: "Streaming events from POST /api/v1/chat") {
            HStack(spacing: 12) {
                Picker("Filter", selection: $selectedTimelineFilter) {
                    ForEach(TimelineFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .labelsHidden()
                .frame(width: 140)

                Toggle("Deltas", isOn: $showDeltaEvents)
                    .toggleStyle(.switch)

                Toggle("Debug", isOn: $showDebugEvents)
                    .toggleStyle(.switch)

                Spacer()
            }

            if lmStudio.timeline.isEmpty {
                ContentUnavailableView(
                    "No events yet",
                    systemImage: "waveform",
                    description: Text("Start a session to see chat lifecycle, prompt processing, tool calls, and completion events here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredTimeline.sorted(by: { $0.timestamp < $1.timestamp })) { entry in
                            timelineRow(entry)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func startFreshSession() async {
        guard let mcpServerURL else {
            appModel.appendLog("Cannot start LM Studio: MCP bridge URL is unavailable.", level: .error)
            return
        }
        guard appModel.mcpServerRunning else {
            appModel.appendLog("Cannot start LM Studio: MCP bridge is not running yet.", level: .warning)
            return
        }
        await lmStudio.startFreshSession(mcpServerURL: mcpServerURL)
    }

    private var selectedModelMenuLabel: String {
        if let selectedModel = lmStudio.selectedModel {
            return selectedModel.displayName
        }
        if let preferredModel = lmStudio.models.first(where: { $0.displayName == preferredModelDisplayName }) {
            return preferredModel.displayName
        }
        return "No model selected"
    }

    private func selectPreferredModelIfNeeded() {
        guard lmStudio.selectedModelKey.isEmpty || lmStudio.selectedModel == nil else { return }
        guard let preferredModel = lmStudio.models.first(where: { $0.displayName == preferredModelDisplayName }) else { return }
        lmStudio.selectedModelKey = preferredModel.key
    }

    private var filteredTimeline: [LMStudioEventRecord] {
        lmStudio.timeline.filter { entry in
            if !showDebugEvents && entry.type == "debug.sse" { return false }

            let isDelta = entry.type.hasSuffix(".delta") || entry.type == "tool_call.arguments"
            if !showDeltaEvents && isDelta { return false }

            switch selectedTimelineFilter {
            case .all:
                return true
            case .important:
                // Hide the low-signal lifecycle noise; keep starts/ends, tool boundaries, and errors.
                let importantTypes: Set<String> = [
                    "chat.start",
                    "chat.end",
                    "model_load.start",
                    "model_load.end",
                    "prompt_processing.start",
                    "prompt_processing.end",
                    "reasoning.start",
                    "reasoning.end",
                    "tool_call.start",
                    "tool_call.success",
                    "tool_call.failure",
                    "message.start",
                    "message.end",
                    "error"
                ]
                return importantTypes.contains(entry.type)
            case .chat:
                return entry.type.hasPrefix("chat.")
            case .model:
                return entry.type.hasPrefix("model_load.")
            case .prompt:
                return entry.type.hasPrefix("prompt_processing.")
            case .reasoning:
                return entry.type.hasPrefix("reasoning.")
            case .tool:
                return entry.type.hasPrefix("tool_call.")
            case .message:
                return entry.type.hasPrefix("message.")
            case .error:
                return entry.type == "error"
            }
        }
    }

    private func openLMStudioApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "LM Studio"]

        do {
            try process.run()
            appModel.appendLog("Requested LM Studio app launch.")
        } catch {
            appModel.appendLog("Failed to open LM Studio: \(error.localizedDescription)", level: .error)
        }
    }

    private func fieldRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            content()
        }
    }

    private func card<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func infoPill(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func smallLabel(_ title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    private func chip(title: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(color)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 150, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    private func outputBlock(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint.opacity(0.7))
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(text.isEmpty ? "Waiting for text..." : text)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 120, maxHeight: 220, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func timelineRow(_ entry: LMStudioEventRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color(for: entry.severity).opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon(for: entry.severity))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color(for: entry.severity))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let detail = entry.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }

                if let progress = entry.progress {
                    ProgressView(value: progress)
                        .tint(color(for: entry.severity))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color(for: entry.severity).opacity(0.06))
        )
    }

    private func icon(for severity: LMStudioEventSeverity) -> String {
        switch severity {
        case .neutral:
            return "circle"
        case .progress:
            return "hourglass"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        case .tool:
            return "wrench.and.screwdriver"
        }
    }

    private var statusColor: Color {
        if lmStudio.isRefreshingModels && !lmStudio.isSessionActive {
            return .blue
        }
        switch lmStudio.sessionState {
        case .idle:
            return .secondary
        case .refreshingModels:
            return .blue
        case .starting:
            return .orange
        case .running:
            return .green
        case .pausing:
            return .orange
        case .paused:
            return .yellow
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private func color(for severity: LMStudioEventSeverity) -> Color {
        switch severity {
        case .neutral:
            return .secondary
        case .progress:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .tool:
            return .teal
        }
    }
}
