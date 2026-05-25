import Foundation

enum MCPToolGroup: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case chats
    case issues
    case memories
    case sensitiveData
    case clientVoice
    case utilities

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chats:
            return "Chats"
        case .issues:
            return "Issues"
        case .memories:
            return "Memories"
        case .sensitiveData:
            return "Sensitive Data"
        case .clientVoice:
            return "Client Voice"
        case .utilities:
            return "Utilities"
        }
    }
}
