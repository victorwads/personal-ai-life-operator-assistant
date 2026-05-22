import Foundation

enum ConversationAccessMode: String, CaseIterable, Identifiable {
    case allowAllExceptDeny
    case denyAllExceptAllow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allowAllExceptDeny:
            return "Allow all (except Deny list)"
        case .denyAllExceptAllow:
            return "Deny all (except Allow list)"
        }
    }

    var helpText: String {
        switch self {
        case .allowAllExceptDeny:
            return "Default: conversations are allowed unless they are explicitly denied."
        case .denyAllExceptAllow:
            return "Locked down: conversations are denied unless they are explicitly allowed."
        }
    }
}

