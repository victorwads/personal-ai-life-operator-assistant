import Foundation

enum SpeechSpeakerError: Error, LocalizedError {
    case notImplemented(String)
    case processExited(status: Int32)

    var errorDescription: String? {
        switch self {
        case let .notImplemented(message):
            return message
        case let .processExited(status):
            return "Speech command exited with status \(status)."
        }
    }
}
