import Foundation

extension AIConnectionReasoningEffort {
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
}
