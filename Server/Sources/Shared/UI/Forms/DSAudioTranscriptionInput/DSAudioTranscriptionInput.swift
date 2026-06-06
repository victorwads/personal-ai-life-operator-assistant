import SwiftUI

struct DSAudioTranscriptionInput<Controller: DSAudioTranscriptionController>: View {
    let mode: DSAudioTranscriptionInputMode
    @Binding var text: String
    @ObservedObject var controller: Controller
    let placeholder: String
    let config: DSAudioTranscriptionInputConfig

    @FocusState private var isFocused: Bool

    init(
        mode: DSAudioTranscriptionInputMode,
        text: Binding<String>,
        controller: Controller,
        placeholder: String,
        config: DSAudioTranscriptionInputConfig = .init()
    ) {
        self.mode = mode
        _text = text
        _controller = ObservedObject(wrappedValue: controller)
        self.placeholder = placeholder
        self.config = config
    }

    var body: some View {
        VStack(alignment: .leading, spacing: mode == .textarea ? 10 : 8) {
            fieldSection

            if shouldShowPreviewSection {
                previewSection
            }

            if config.showsStatusBar {
                statusSection
            }
        }
        .onAppear {
            appendCompletedSegmentsIfNeeded()
        }
        .onReceive(controller.objectWillChange) { _ in
            appendCompletedSegmentsIfNeeded()
        }
        .onChange(of: isFocused) { _, newValue in
            handleFocusChange(newValue)
        }
    }

    @ViewBuilder
    private var fieldSection: some View {
        switch mode {
        case .input:
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(fieldBackground)
        case .textarea:
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(minHeight: 124)
                    .padding(8)

                if text.isEmpty {
                    placeholderView
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(fieldBackground)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !controller.livePartialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    previewLabel("Live transcription")
                    Text(controller.livePartialText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if config.showsSegments, !controller.processingSegments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    previewLabel("Processing segments")

                    ForEach(controller.processingSegments) { segment in
                        HStack(alignment: .top, spacing: 8) {
                            DSBadge(
                                "S\(segment.index)",
                                secondaryText: segmentStatusText(segment.status),
                                style: segmentBadgeStyle(segment.status)
                            )

                            Text(segment.previewText.isEmpty ? "No preview text yet." : segment.previewText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            if let errorMessage = failedMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private var statusSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            Text(statusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            DSBadge(
                "Segments",
                secondaryText: "\(controller.completedSegmentCount)/\(controller.totalSegmentCount)",
                style: .neutral
            )

            DSBadge(
                "Processing",
                secondaryText: "\(controller.processingSegmentCount)",
                style: controller.processingSegmentCount > 0 ? .warning : .neutral
            )

            Spacer(minLength: 8)

            if shouldShowCancelButton {
                Button("Cancel") {
                    controller.cancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button(primaryActionTitle) {
                handlePrimaryAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var placeholderView: some View {
        Text(placeholder)
            .foregroundStyle(.tertiary)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.28),
                        lineWidth: 1
                    )
            )
    }

    private var shouldShowPreviewSection: Bool {
        !controller.livePartialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        (config.showsSegments && !controller.processingSegments.isEmpty) ||
        failedMessage != nil
    }

    private var shouldShowCancelButton: Bool {
        switch controller.status {
        case .listening, .processing, .stopping, .failed:
            return true
        case .idle, .stopped:
            return false
        }
    }

    private var primaryActionTitle: String {
        shouldShowStopAction ? "Stop" : "Start"
    }

    private var shouldShowStopAction: Bool {
        switch controller.status {
        case .listening, .processing, .stopping:
            return true
        case .idle, .stopped, .failed:
            return false
        }
    }

    private var statusLabel: String {
        switch controller.status {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening"
        case .processing:
            return "Processing"
        case .stopping:
            return "Stopping"
        case .stopped:
            return "Stopped"
        case .failed:
            return "Failed"
        }
    }

    private var statusIcon: String {
        switch controller.status {
        case .idle, .stopped:
            return "mic"
        case .listening:
            return "mic.fill"
        case .processing:
            return "waveform"
        case .stopping:
            return "mic.slash"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case .idle, .stopped:
            return .secondary
        case .listening:
            return .red
        case .processing, .stopping:
            return .orange
        case .failed:
            return .red
        }
    }

    private var failedMessage: String? {
        if case let .failed(message) = controller.status {
            return message
        }

        return nil
    }

    private func handlePrimaryAction() {
        if shouldShowStopAction {
            controller.stop()
        } else {
            controller.start()
        }
    }

    private func handleFocusChange(_ isFocused: Bool) {
        if isFocused, config.autoStartOnFocus {
            controller.start()
        } else if !isFocused, config.stopOnFocusLost {
            controller.stop()
        }
    }

    private func appendCompletedSegmentsIfNeeded() {
        var appendedTexts: [String] = []

        while let nextText = controller.consumeCompletedSegmentTextToAppend() {
            let trimmedText = nextText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                appendedTexts.append(trimmedText)
            }
        }

        guard !appendedTexts.isEmpty else { return }

        let addition = appendedTexts.joined(separator: "\n")

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = addition
        } else {
            text += separatorBeforeAppending(to: text, addition: addition) + addition
        }
    }

    private func separatorBeforeAppending(to currentText: String, addition: String) -> String {
        guard let lastCharacter = currentText.last else { return "" }
        if lastCharacter == "\n" {
            return ""
        }

        let additionStartsWithPunctuation = addition.first.map { ",.;:!?)]}".contains($0) } ?? false
        if additionStartsWithPunctuation {
            return ""
        }

        if ".!?".contains(lastCharacter) {
            return "\n"
        }

        if lastCharacter.isWhitespace {
            return ""
        }

        return " "
    }

    private func previewLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func segmentStatusText(_ status: DSAudioTranscriptionSegment.Status) -> String {
        switch status {
        case .recording:
            return "Recording"
        case .queued:
            return "Queued"
        case .transcribing:
            return "Transcribing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    private func segmentBadgeStyle(_ status: DSAudioTranscriptionSegment.Status) -> DSBadge.Style {
        switch status {
        case .recording, .queued:
            return .warning
        case .transcribing:
            return .info
        case .completed:
            return .success
        case .failed:
            return .danger
        }
    }
}
