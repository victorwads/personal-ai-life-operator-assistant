import Foundation

enum AIConnectionCacheMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case disabled

    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .disabled:
            return "Disabled"
        }
    }
}
