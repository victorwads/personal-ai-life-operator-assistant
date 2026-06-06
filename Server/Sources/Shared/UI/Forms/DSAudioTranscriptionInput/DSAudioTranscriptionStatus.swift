import Foundation

enum DSAudioTranscriptionStatus {
    case idle
    case listening
    case processing
    case stopping
    case stopped
    case failed(String)
}
