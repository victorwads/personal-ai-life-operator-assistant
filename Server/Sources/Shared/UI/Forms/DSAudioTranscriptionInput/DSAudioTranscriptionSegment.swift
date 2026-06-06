import Foundation

struct DSAudioTranscriptionSegment: Identifiable, Equatable {
    enum Status {
        case recording
        case queued
        case transcribing
        case completed
        case failed
    }

    let id: UUID
    var index: Int
    var status: Status
    var previewText: String
}
