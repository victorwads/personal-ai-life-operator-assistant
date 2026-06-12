import Combine
import Foundation

@MainActor
final class DSAudioTranscriptionInputPreviewController: DSAudioTranscriptionController {
    @Published var lifecycle: DSAudioTranscriptionLifecycle
    @Published var isListening: Bool
    @Published var isSilent: Bool
    @Published var isPostProcessing: Bool
    @Published var statusText: String?
    @Published var errorText: String?
    @Published var inlineSegments: [DSAudioTranscriptionSegment]
    @Published var committedTextAppendRevision: Int = 0
    @Published var textMutationRevision: Int = 0

    private var pendingTextMutations: [DSAudioTextMutation] = []

    init(
        lifecycle: DSAudioTranscriptionLifecycle = .idle,
        isListening: Bool = false,
        isSilent: Bool = false,
        isPostProcessing: Bool = false,
        statusText: String? = nil,
        errorText: String? = nil,
        inlineSegments: [DSAudioTranscriptionSegment] = []
    ) {
        self.lifecycle = lifecycle
        self.isListening = isListening
        self.isSilent = isSilent
        self.isPostProcessing = isPostProcessing
        self.statusText = statusText
        self.errorText = errorText
        self.inlineSegments = inlineSegments
    }

    var queuedSegmentCount: Int {
        inlineSegments.filter { $0.kind == .queued }.count
    }

    var processingSegmentCount: Int {
        inlineSegments.filter { $0.kind == .whisperProcessing }.count
    }

    func consumeTextMutation() -> DSAudioTextMutation? {
        guard !pendingTextMutations.isEmpty else {
            return nil
        }

        return pendingTextMutations.removeFirst()
    }

    func startListening() {
        isListening = true
        isSilent = false
        lifecycle = .listening
        statusText = "Listening"
    }

    func stopListening() {
        isListening = false

        if isPostProcessing || queuedSegmentCount > 0 {
            lifecycle = .postProcessing
            statusText = makeProcessingStatus()
        } else {
            lifecycle = .idle
            statusText = nil
        }
    }

    func cancelAll() {
        isListening = false
        isSilent = false
        isPostProcessing = false
        lifecycle = .idle
        statusText = nil
        errorText = nil
        inlineSegments = []
        pendingTextMutations = []
    }

    func previewCommitText(_ text: String) {
        pendingTextMutations.append(
            .appendCommittedText(
                DSAudioCommittedTextAppend(
                    text: text,
                    shouldStartNewParagraph: false
                )
            )
        )
        textMutationRevision += 1
        committedTextAppendRevision += 1
    }

    private func makeProcessingStatus() -> String {
        if queuedSegmentCount > 0 && isPostProcessing {
            return "Post-processing • Queue: \(queuedSegmentCount)"
        }

        if isPostProcessing {
            return "Post-processing"
        }

        if queuedSegmentCount > 0 {
            return "Queue: \(queuedSegmentCount)"
        }

        return ""
    }
}
