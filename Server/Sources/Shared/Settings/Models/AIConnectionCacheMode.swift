import Foundation

public enum AIConnectionCacheMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case disabled

    public var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .disabled:
            return "Disabled"
        }
    }
}
