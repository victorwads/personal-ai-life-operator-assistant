import Foundation

struct DSAudioTranscriptionSegment: Identifiable, Equatable {
    let id: UUID
    var kind: DSAudioTranscriptionSegmentKind
    var text: String
    var audioSamplesCount: Int?

    init(
        id: UUID = UUID(),
        kind: DSAudioTranscriptionSegmentKind,
        text: String,
        audioSamplesCount: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.audioSamplesCount = audioSamplesCount
    }
}
