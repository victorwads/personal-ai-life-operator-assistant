import Foundation

enum DSAudioTranscriptionLifecycle: Equatable {
    case idle
    case listening
    case silent
    case recognizing
    case queued
    case postProcessing
    case error
}
