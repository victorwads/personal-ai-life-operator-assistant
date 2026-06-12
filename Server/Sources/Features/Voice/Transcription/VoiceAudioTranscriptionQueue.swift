import Foundation

@MainActor
final class VoiceAudioTranscriptionQueue {
    private(set) var realtimeSegment: VoiceAudioTranscriptionSegment?
    private(set) var processingSegment: VoiceAudioTranscriptionSegment?
    private(set) var queuedSegments: [VoiceAudioTranscriptionSegment] = []

    var hasPendingWork: Bool {
        processingSegment != nil || !queuedSegments.isEmpty
    }

    func updateRealtimeText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            let changed = realtimeSegment != nil
            realtimeSegment = nil
            return changed
        }

        if realtimeSegment == nil {
            realtimeSegment = VoiceAudioTranscriptionSegment(
                appleText: trimmed,
                state: .realtime
            )
            return true
        } else {
            let changed = realtimeSegment?.appleText != trimmed
            if changed {
                realtimeSegment?.appleText = trimmed
                realtimeSegment?.updatedAt = Date()
            }
            return changed
        }
    }

    func closeRealtimeSegment(audioSamples: [Float]) -> VoiceAudioTranscriptionSegment? {
        guard var segment = realtimeSegment else {
            return nil
        }

        realtimeSegment = nil

        segment.state = .queued
        segment.audioSamples = audioSamples
        segment.updatedAt = Date()

        queuedSegments.append(segment)
        return segment
    }

    func takeNextForProcessing() -> VoiceAudioTranscriptionSegment? {
        guard processingSegment == nil else {
            return nil
        }

        guard !queuedSegments.isEmpty else {
            return nil
        }

        var segment = queuedSegments.removeFirst()
        segment.state = .processing
        segment.updatedAt = Date()

        processingSegment = segment
        return segment
    }

    func finishProcessing(
        segmentID: UUID,
        refinedText: String
    ) -> VoiceAudioTranscriptionSegment? {
        guard var segment = processingSegment, segment.id == segmentID else {
            return nil
        }

        segment.refinedText = refinedText
        segment.state = .committed
        segment.updatedAt = Date()

        processingSegment = nil
        return segment
    }

    func failProcessing(
        segmentID: UUID,
        message: String
    ) -> VoiceAudioTranscriptionSegment? {
        guard var segment = processingSegment, segment.id == segmentID else {
            return nil
        }

        segment.state = .failed(message)
        segment.updatedAt = Date()

        processingSegment = nil
        return segment
    }

    func clearAll() {
        realtimeSegment = nil
        processingSegment = nil
        queuedSegments = []
    }

    func makeInlineSegments() -> [DSAudioTranscriptionSegment] {
        var result: [DSAudioTranscriptionSegment] = []

        if let processingSegment {
            result.append(
                DSAudioTranscriptionSegment(
                    id: processingSegment.id,
                    kind: .whisperProcessing,
                    text: processingSegment.appleText,
                    audioSamplesCount: processingSegment.audioSamples.count
                )
            )
        }

        result.append(
            contentsOf: queuedSegments.map {
                DSAudioTranscriptionSegment(
                    id: $0.id,
                    kind: .queued,
                    text: $0.appleText,
                    audioSamplesCount: $0.audioSamples.count
                )
            }
        )

        if let realtimeSegment {
            result.append(
                DSAudioTranscriptionSegment(
                    id: realtimeSegment.id,
                    kind: .appleRealtime,
                    text: realtimeSegment.appleText,
                    audioSamplesCount: nil
                )
            )
        }

        return result
    }
}
