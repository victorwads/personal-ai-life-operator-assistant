import Foundation

@MainActor
final class WhatsAppCrawlingLogStore: ObservableObject {
    @Published private(set) var entries: [WhatsAppCrawlingLogEntry] = []
    private let maxEntries = 1_000

    func append(source: String, _ message: String) {
        let entry = WhatsAppCrawlingLogEntry(source: source, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        print("[WhatsAppCrawling][\(source)] \(message)")
    }

    func clear() {
        entries.removeAll()
    }
}
