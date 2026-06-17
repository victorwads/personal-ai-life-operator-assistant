import Foundation

public enum AIConnectionReasoningEffort: String, Codable, CaseIterable, Sendable {
    case omit
    case off
    case enabled
    case none
    case low
    case medium
    case high
    case xhigh
    case qwenOff

    public var displayName: String {
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
