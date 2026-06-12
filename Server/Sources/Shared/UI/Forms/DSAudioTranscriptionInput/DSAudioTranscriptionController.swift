import Combine
import Foundation

struct DSAudioCommittedTextAppend {
    let text: String
    let shouldStartNewParagraph: Bool
}

@MainActor
protocol DSAudioTranscriptionController: ObservableObject {
    var lifecycle: DSAudioTranscriptionLifecycle { get }

    var isListening: Bool { get }
    var isSilent: Bool { get }
    var isPostProcessing: Bool { get }

    var statusText: String? { get }
    var errorText: String? { get }

    var inlineSegments: [DSAudioTranscriptionSegment] { get }

    var queuedSegmentCount: Int { get }
    var processingSegmentCount: Int { get }
    var committedTextAppendRevision: Int { get }
    var textMutationRevision: Int { get }

    func startListening()
    func stopListening()
    func cancelAll()

    func consumeTextMutation() -> DSAudioTextMutation?
}
