import Foundation

enum ClientVoiceEventKind: String, Codable, CaseIterable {
    case speak
    case ask
}

enum ClientVoiceAskStatus: String, Codable, CaseIterable {
    case pending
    case answered
}

struct ClientVoiceEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ClientVoiceEventKind
    let createdAt: Date

    var text: String?

    var prompt: String?
    var transcript: String?
    var askStatus: ClientVoiceAskStatus?
    var answeredAt: Date?
}

