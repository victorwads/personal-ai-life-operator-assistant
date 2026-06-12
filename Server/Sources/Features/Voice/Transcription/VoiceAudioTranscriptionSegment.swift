import Foundation

struct VoiceAudioTranscriptionSegment: Identifiable, Equatable {
    enum State: Equatable {
        case realtime
        case queued
        case processing
        case committed
        case failed(String)
    }

    let id: UUID
    var appleText: String
    var audioSamples: [Float]
    var refinedText: String?
    var state: State
    var startedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        appleText: String,
        audioSamples: [Float] = [],
        refinedText: String? = nil,
        state: State,
        startedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.appleText = appleText
        self.audioSamples = audioSamples
        self.refinedText = refinedText
        self.state = state
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    var bestText: String {
        let refined = refinedText?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let refined, !refined.isEmpty {
            return refined
        }

        return appleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
