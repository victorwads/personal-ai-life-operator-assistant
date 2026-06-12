import SwiftUI

struct DSAudioTranscriptionInput<Controller: DSAudioTranscriptionController>: View {
    let title: String
    let placeholder: String
    let mode: DSAudioTranscriptionInputMode
    let config: DSAudioTranscriptionInputConfig

    @Binding var text: String
    @ObservedObject var controller: Controller

    init(
        title: String,
        placeholder: String = "",
        mode: DSAudioTranscriptionInputMode = .textarea,
        text: Binding<String>,
        controller: Controller,
        config: DSAudioTranscriptionInputConfig = .default
    ) {
        self.title = title
        self.placeholder = placeholder
        self.mode = mode
        self.config = config
        self._text = text
        self._controller = ObservedObject(wrappedValue: controller)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if config.showsHeader {
                header
            }

            editor

            if config.showsFooter, shouldShowFooter {
                footer
            }
        }
        .opacity(config.isEnabled ? 1 : 0.72)
        .onAppear {
            applyPendingTextMutationsIfNeeded()
        }
        .onChange(of: controller.textMutationRevision) { _, _ in
            applyPendingTextMutationsIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                if controller.isListening {
                    controller.stopListening()
                } else {
                    controller.startListening()
                }
            } label: {
                Image(systemName: controller.isListening ? "mic.fill" : "mic")
                    .imageScale(.medium)
                    .foregroundStyle(controller.isListening ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(controller.isListening ? "Stop listening" : "Start listening")
            .disabled(!config.isEnabled)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            DSAudioTranscriptionTextView(
                text: $text,
                placeholder: "",
                segments: controller.inlineSegments,
                isEnabled: config.isEnabled,
                badgePalette: config.badgePalette,
                autoScrollsToBottom: config.autoScrollsToBottom,
                autoScrollUserOverrideDistance: config.autoScrollUserOverrideDistance,
                shouldAutoScrollToBottom: shouldAutoScrollToBottom,
                forceFollowBottom: shouldForceFollowBottom
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            if text.isEmpty && controller.inlineSegments.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: heightForMode, maxHeight: config.maxHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .fill(Color(nsColor: .textBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let errorText = trimmed(controller.errorText) {
                Text(errorText)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if hasStructuredStatus {
                statusLegend
            } else if let statusText = usefulStatusText {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(minHeight: 14)
    }

    private var shouldShowFooter: Bool {
        trimmed(controller.errorText) != nil || hasStructuredStatus || usefulStatusText != nil
    }

    private var usefulStatusText: String? {
        trimmed(controller.statusText)
    }

    private var isRecognizing: Bool {
        controller.inlineSegments.contains { $0.kind == .appleRealtime } ||
        controller.lifecycle == .recognizing
    }

    private var hasStructuredStatus: Bool {
        controller.isPostProcessing ||
        controller.queuedSegmentCount > 0 ||
        isRecognizing
    }

    private var statusLegend: some View {
        HStack(spacing: 8) {
            if controller.isPostProcessing {
                statusLegendItem(
                    kind: .whisperProcessing,
                    title: "Post-processing"
                )
            }

            if controller.queuedSegmentCount > 0 {
                statusLegendItem(
                    kind: .queued,
                    title: "Queue: \(controller.queuedSegmentCount)"
                )
            }

            if isRecognizing {
                statusLegendItem(
                    kind: .appleRealtime,
                    title: "Recognizing"
                )
            }
        }
    }

    private func statusLegendItem(
        kind: DSAudioTranscriptionSegmentKind,
        title: String
    ) -> some View {
        HStack(spacing: 4) {
            segmentStatusIcon(kind)
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(statusColor(for: kind))
        .lineLimit(1)
    }

    private func statusColor(for kind: DSAudioTranscriptionSegmentKind) -> Color {
        Color(
            nsColor: DSAudioTranscriptionTextViewAttributes.badgeForegroundColor(
                for: kind,
                badgePalette: config.badgePalette
            )
        )
    }

    @ViewBuilder
    private func segmentStatusIcon(_ kind: DSAudioTranscriptionSegmentKind) -> some View {
        switch kind.icon {
        case .text(let value):
            Text(value)
                .font(.caption2.weight(.semibold))

        case .systemSymbol(let symbolName):
            Image(systemName: symbolName)
                .font(.caption2.weight(.semibold))
        }
    }

    private var heightForMode: CGFloat {
        switch mode {
        case .input:
            return max(44, min(config.minHeight, 44))
        case .textarea:
            return config.minHeight
        }
    }

    private var borderColor: Color {
        if trimmed(controller.errorText) != nil {
            return .red.opacity(0.65)
        }

        if controller.isListening {
            return .accentColor.opacity(0.75)
        }

        return Color(nsColor: .separatorColor)
    }

    private var shouldAutoScrollToBottom: Bool {
        controller.isListening ||
        controller.lifecycle == .recognizing ||
        controller.isPostProcessing ||
        controller.queuedSegmentCount > 0 ||
        !controller.inlineSegments.isEmpty
    }

    private var shouldForceFollowBottom: Bool {
        controller.isListening ||
        controller.lifecycle == .recognizing ||
        controller.isPostProcessing
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func applyPendingTextMutationsIfNeeded() {
        while let textMutation = controller.consumeTextMutation() {
            applyTextMutation(textMutation)
        }
    }

    private func applyTextMutation(_ mutation: DSAudioTextMutation) {
        switch mutation {
        case .insertParagraphBreak:
            insertParagraphBreakIfNeeded()
        case .appendCommittedText(let append):
            appendCommittedText(append)
        }
    }

    private func insertParagraphBreakIfNeeded() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }

        if text.hasSuffix("\n\n") {
            return
        }

        if text.hasSuffix("\n") {
            text += "\n"
        } else {
            text += "\n\n"
        }
    }

    private func appendCommittedText(_ append: DSAudioCommittedTextAppend) {
        let trimmedCommittedText = append.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCommittedText.isEmpty else {
            return
        }

        if append.shouldStartNewParagraph {
            insertParagraphBreakIfNeeded()
        }

        let currentText = text

        if currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = trimmedCommittedText
            return
        }

        if currentText.hasSuffix("\n") {
            text = currentText + trimmedCommittedText
        } else {
            text = currentText + " " + trimmedCommittedText
        }
    }
}
