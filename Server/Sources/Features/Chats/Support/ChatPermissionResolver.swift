import Foundation

enum ChatPermissionResolver {
    static func isChatAllowed(_ chat: Chat, mode: ChatPermissionMode) -> Bool {
        isPermissionAllowed(chat.permission, mode: mode)
    }

    static func isPermissionAllowed(_ permission: ChatPermission?, mode: ChatPermissionMode) -> Bool {
        switch mode {
        case .allowAllExceptDenied:
            return permission != .denied
        case .denyAllExceptAllowed:
            return permission == .allowed
        }
    }
}
