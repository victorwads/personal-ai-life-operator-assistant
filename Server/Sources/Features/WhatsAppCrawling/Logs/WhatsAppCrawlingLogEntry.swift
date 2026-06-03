import Foundation

struct WhatsAppCrawlingLogEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let source: String
    let message: String

    init(id: UUID = UUID(), date: Date = Date(), source: String, message: String) {
        self.id = id
        self.date = date
        self.source = source
        self.message = message
    }
}
