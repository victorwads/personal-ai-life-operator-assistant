import Foundation

struct AssistantContact: PersistableModel, Equatable, Sendable {
    var id: String?
    var displayName: String
    var googlePersonId: String?
    var whatsappChatId: String?
    var primaryPhone: String?
    var primaryEmail: String?
}
