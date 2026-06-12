import Foundation

typealias FakeAudioTranscriptionController = DSAudioTranscriptionInputPreviewController

extension DSAudioTranscriptionInputPreviewController {
    static func idle() -> DSAudioTranscriptionInputPreviewController {
        DSAudioTranscriptionInputPreviewController(
            lifecycle: .idle,
            isListening: false
        )
    }

    static func activeListeningOnly() -> DSAudioTranscriptionInputPreviewController {
        DSAudioTranscriptionInputPreviewController(
            lifecycle: .recognizing,
            isListening: true,
            statusText: "Recognizing",
            inlineSegments: [
                DSAudioTranscriptionSegment(
                    kind: .appleRealtime,
                    text: "I am speaking some words here..."
                )
            ]
        )
    }

    static func activeListeningAndProcessing() -> DSAudioTranscriptionInputPreviewController {
        DSAudioTranscriptionInputPreviewController(
            lifecycle: .recognizing,
            isListening: true,
            isPostProcessing: true,
            statusText: "Post-processing • Recognizing",
            inlineSegments: [
                DSAudioTranscriptionSegment(
                    kind: .whisperProcessing,
                    text: "Checking backend records..."
                ),
                DSAudioTranscriptionSegment(
                    kind: .appleRealtime,
                    text: "I wanted to confirm the details before I send the update."
                )
            ]
        )
    }

    static func stoppingProcessing() -> DSAudioTranscriptionInputPreviewController {
        DSAudioTranscriptionInputPreviewController(
            lifecycle: .postProcessing,
            isListening: false,
            isSilent: true,
            isPostProcessing: true,
            statusText: "Post-processing • Queue: 1",
            inlineSegments: [
                DSAudioTranscriptionSegment(
                    kind: .queued,
                    text: "I can share the latest issue summary next."
                ),
                DSAudioTranscriptionSegment(
                    kind: .whisperProcessing,
                    text: "Still waiting for upload..."
                )
            ]
        )
    }

    static func stopped() -> DSAudioTranscriptionInputPreviewController {
        DSAudioTranscriptionInputPreviewController(
            lifecycle: .idle,
            isListening: false
        )
    }

    static func failed() -> DSAudioTranscriptionInputPreviewController {
        DSAudioTranscriptionInputPreviewController(
            lifecycle: .error,
            isListening: false,
            errorText: "Microphone permission is missing."
        )
    }
}
