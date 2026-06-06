import Foundation

@MainActor
final class FakeAudioTranscriptionController: DSAudioTranscriptionController {
    @Published private(set) var status: DSAudioTranscriptionStatus
    @Published private(set) var livePartialText: String
    @Published private(set) var processingSegments: [DSAudioTranscriptionSegment]

    private(set) var totalSegmentCount: Int
    private(set) var processingSegmentCount: Int
    private(set) var completedSegmentCount: Int

    private var queuedCompletedTexts: [String]

    init(
        status: DSAudioTranscriptionStatus,
        livePartialText: String = "",
        processingSegments: [DSAudioTranscriptionSegment] = [],
        totalSegmentCount: Int = 0,
        processingSegmentCount: Int = 0,
        completedSegmentCount: Int = 0,
        queuedCompletedTexts: [String] = []
    ) {
        self.status = status
        self.livePartialText = livePartialText
        self.processingSegments = processingSegments
        self.totalSegmentCount = totalSegmentCount
        self.processingSegmentCount = processingSegmentCount
        self.completedSegmentCount = completedSegmentCount
        self.queuedCompletedTexts = queuedCompletedTexts
    }

    func start() {
        if case .failed = status {
            status = .listening
            livePartialText = "Retrying transcription..."
            processingSegments = []
            processingSegmentCount = 0
            return
        }

        status = .listening
        if livePartialText.isEmpty {
            livePartialText = "Listening for the next phrase..."
        }
    }

    func stop() {
        status = processingSegments.isEmpty ? .stopped : .stopping
        if !processingSegments.isEmpty {
            status = .processing
        }
        livePartialText = ""
    }

    func cancel() {
        status = .idle
        livePartialText = ""
        processingSegments = []
        processingSegmentCount = 0
        queuedCompletedTexts = []
    }

    func consumeCompletedSegmentTextToAppend() -> String? {
        guard !queuedCompletedTexts.isEmpty else { return nil }
        return queuedCompletedTexts.removeFirst()
    }
}

extension FakeAudioTranscriptionController {
    static func idle() -> FakeAudioTranscriptionController {
        FakeAudioTranscriptionController(status: .idle)
    }

    static func listening() -> FakeAudioTranscriptionController {
        FakeAudioTranscriptionController(
            status: .listening,
            livePartialText: "I wanted to confirm the details before I send the update.",
            totalSegmentCount: 1,
            processingSegmentCount: 1,
            completedSegmentCount: 0
        )
    }

    static func processing() -> FakeAudioTranscriptionController {
        FakeAudioTranscriptionController(
            status: .processing,
            livePartialText: "",
            processingSegments: [
                DSAudioTranscriptionSegment(
                    id: UUID(),
                    index: 2,
                    status: .transcribing,
                    previewText: "I can share the latest issue summary next."
                ),
                DSAudioTranscriptionSegment(
                    id: UUID(),
                    index: 3,
                    status: .queued,
                    previewText: "Still waiting for upload..."
                )
            ],
            totalSegmentCount: 3,
            processingSegmentCount: 2,
            completedSegmentCount: 1
        )
    }

    static func completedWaitingToAppend() -> FakeAudioTranscriptionController {
        FakeAudioTranscriptionController(
            status: .stopped,
            totalSegmentCount: 2,
            processingSegmentCount: 0,
            completedSegmentCount: 2,
            queuedCompletedTexts: [
                "This confirmed sentence was waiting to append.",
                "Here is the follow-up sentence from the next finalized segment."
            ]
        )
    }

    static func failed() -> FakeAudioTranscriptionController {
        FakeAudioTranscriptionController(
            status: .failed("Microphone permission is missing."),
            processingSegments: [
                DSAudioTranscriptionSegment(
                    id: UUID(),
                    index: 1,
                    status: .failed,
                    previewText: "Could not finish this segment."
                )
            ],
            totalSegmentCount: 1,
            processingSegmentCount: 1,
            completedSegmentCount: 0
        )
    }
}
