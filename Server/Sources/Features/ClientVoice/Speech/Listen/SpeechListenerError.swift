import Foundation

enum SpeechListenerError: Error, LocalizedError {
    case notImplemented(String)
    case unauthorized
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return message
        case .unauthorized:
            return "Speech recognition or microphone permission denied."
        case .recognizerUnavailable:
            return "Speech recognizer is not available for the requested locale."
        }
    }
}
