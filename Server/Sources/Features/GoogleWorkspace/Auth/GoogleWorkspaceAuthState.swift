import Foundation

enum GoogleWorkspaceAuthState: Codable, Equatable, Sendable, CustomStringConvertible {
    case disconnected
    case connecting(state: String)
    case connected(scopes: [String], expiresAt: Date)

    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected(let scopes, let expiresAt):
            let dateStr = ISO8601DateFormatter().string(from: expiresAt)
            return "Connected (Scopes: \(scopes.joined(separator: ", ")), Expires: \(dateStr))"
        }
    }
}
