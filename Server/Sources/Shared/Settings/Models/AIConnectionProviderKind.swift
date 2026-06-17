import Foundation

public enum AIConnectionProviderKind: String, Codable, CaseIterable, Sendable {
    case openRouter
    case lmStudio
    case openAICompatible
    case aiRuntime

    public var displayName: String {
        switch self {
        case .openRouter:
            return "OpenRouter"
        case .lmStudio:
            return "LM Studio"
        case .openAICompatible:
            return "OpenAI-Compatible"
        case .aiRuntime:
            return "Local AIRuntime (MLX)"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openRouter:
            return "https://openrouter.ai/api/v1"
        case .lmStudio:
            return "http://localhost:1234/v1"
        case .openAICompatible:
            return ""
        case .aiRuntime:
            return ""
        }
    }
}
