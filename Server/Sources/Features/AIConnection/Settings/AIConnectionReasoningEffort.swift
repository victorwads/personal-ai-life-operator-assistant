import Foundation

enum AIConnectionReasoningEffort: String, Codable, CaseIterable, Sendable {
    case off
    case none
    case low
    case medium
    case high
    case xhigh
    case qwenOff

    var reasoningPayload: OpenAICompatibleReasoningPayload? {
        switch self {
        case .off:
            return .off
        case .none, .low, .medium, .high, .xhigh:
            return .effort(rawValue)
        case .qwenOff:
            return nil
        }
    }

    var extraBody: OpenAICompatibleExtraBody? {
        switch self {
        case .qwenOff:
            return OpenAICompatibleExtraBody(
                chatTemplateKwargs: OpenAICompatibleChatTemplateKwargs(enableThinking: false)
            )
        case .off, .none, .low, .medium, .high, .xhigh:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .off:
            return "Off"
        case .none:
            return "None"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .xhigh:
            return "Ex-High"
        case .qwenOff:
            return "Qwen Off"
        }
    }
}
