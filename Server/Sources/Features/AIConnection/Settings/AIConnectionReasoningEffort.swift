import Foundation

enum AIConnectionReasoningEffort: String, Codable, CaseIterable, Sendable {
    case omit
    case off
    case enabled
    case none
    case low
    case medium
    case high
    case xhigh
    case qwenOff

    var reasoningPayload: OpenAICompatibleReasoningPayload? {
        switch self {
        case .omit:
            return nil
        case .off:
            return .off
        case .enabled:
            return .enabled
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
        case .omit, .off, .enabled, .none, .low, .medium, .high, .xhigh:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .omit:
            return "Omit"
        case .off:
            return "Off"
        case .enabled:
            return "Enabled"
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
