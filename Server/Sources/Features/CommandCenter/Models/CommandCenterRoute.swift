import Foundation

enum CommandCenterRoute: String, CaseIterable, Identifiable, Hashable {
    case myProfile
    case issues
    case chats
    case memories
    case sensitiveData
    case clientVoice
    case sentMessages
    case googleWorkspace
    case whatsappWebView
    case whatsappWebYAMLDebug
    case whatsappNativeYAMLDebug
    case whatsappLogs
    case tools
    case aiConnection
    case aiResourceUsage
    case serverLogs
    case settings

    var id: String { rawValue }
}
