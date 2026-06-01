import Foundation

enum CommandCenterRoute: String, CaseIterable, Identifiable, Hashable {
    case myProfile
    case issues
    case chats
    case memories
    case sensitiveData
    case clientVoice
    case sentMessages
    case email
    case calendar
    case whatsappWebView
    case whatsappWebYAMLDebug
    case whatsappNativeYAMLDebug
    case whatsappLogs
    case tools
    case aiConnection
    case serverLogs
    case settings

    var id: String { rawValue }
}
