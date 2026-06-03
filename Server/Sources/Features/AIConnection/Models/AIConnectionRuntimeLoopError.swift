import Foundation

enum AIConnectionRuntimeLoopError: LocalizedError {
    case missingCompletedResponse
    case providerFailure(AIProviderFailure)
    case invalidAssistantText(String, retriesExhausted: Int)

    var errorDescription: String? {
        switch self {
        case .missingCompletedResponse:
            return "Provider stream ended without a completed response event."
        case let .providerFailure(failure):
            return failure.message
        case let .invalidAssistantText(text, retriesExhausted):
            return "Model returned invalid plain assistant text after \(retriesExhausted) corrective retr\(retriesExhausted == 1 ? "y" : "ies"): \(text)"
        }
    }
}
