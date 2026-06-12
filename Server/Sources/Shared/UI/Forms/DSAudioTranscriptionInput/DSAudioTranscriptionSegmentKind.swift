import Foundation

enum DSAudioTranscriptionSegmentIcon: Equatable {
    case text(String)
    case systemSymbol(String)
}

enum DSAudioTranscriptionSegmentKind: String, CaseIterable, Equatable {
    case queued
    case whisperProcessing
    case appleRealtime

    var icon: DSAudioTranscriptionSegmentIcon {
        switch self {
        case .queued:
            return .text("◷")
        case .whisperProcessing:
            return .text("✦")
        case .appleRealtime:
            return .systemSymbol("mic.fill")
        }
    }

    var helpText: String {
        switch self {
        case .queued:
            return "Queued for Whisper post-processing"
        case .whisperProcessing:
            return "Post-processing with Whisper"
        case .appleRealtime:
            return "Realtime Apple Speech recognition"
        }
    }
}
