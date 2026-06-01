import Foundation

enum ChatPermission: String, Codable, CaseIterable, Identifiable, Sendable {
    case allowed
    case denied

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allowed:
            return "Allowed"
        case .denied:
            return "Denied"
        }
    }
}

enum ChatPermissionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case allowAllExceptDenied
    case denyAllExceptAllowed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allowAllExceptDenied:
            return "Allow All Except Denied"
        case .denyAllExceptAllowed:
            return "Deny All Except Allowed"
        }
    }
}

enum ChatPermissionChoice: String, CaseIterable, Identifiable {
    case `default`
    case allowed
    case denied

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .allowed:
            return "Allowed"
        case .denied:
            return "Denied"
        }
    }

    init(permission: ChatPermission?) {
        switch permission {
        case .allowed:
            self = .allowed
        case .denied:
            self = .denied
        case nil:
            self = .default
        }
    }

    var permission: ChatPermission? {
        switch self {
        case .default:
            return nil
        case .allowed:
            return .allowed
        case .denied:
            return .denied
        }
    }
}
