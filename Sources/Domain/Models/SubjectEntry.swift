import Foundation

enum SubjectStatus: String, Codable, CaseIterable {
    case active
    case finished
}

struct SubjectEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var summary: String
    var initialRequest: String
    var details: String?
    var status: SubjectStatus
    var priority: Int
    var participants: [String]
    var nextSteps: [String]
    var eventLog: [EventEntry]

    var whatsappChatId: String?
    var whatsappAfterMessageId: String?
    var gmailThreadId: String?
    var calendarEventId: String?

    let createdAt: Date
    var updatedAt: Date
}

struct EventEntry: Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let description: String
    let source: String?  // ex: "whatsapp", "gmail", "calendar", "manual"
    let author: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), description: String, source: String? = nil, author: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.source = source
        self.author = author
    }
}
