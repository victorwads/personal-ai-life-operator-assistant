import Foundation

enum ClientVoiceAskSendMode: String, CaseIterable, Identifiable, Sendable {
    case handsFree
    case manualSend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .handsFree:
            return "Hands-free"
        case .manualSend:
            return "Manual Send"
        }
    }
}
