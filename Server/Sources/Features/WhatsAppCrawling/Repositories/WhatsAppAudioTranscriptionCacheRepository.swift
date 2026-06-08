import Foundation

protocol WhatsAppAudioTranscriptionCacheRepository: Sendable {
    func getCachedText(profileId: String, audioId: String) async throws -> String?
    func saveCachedText(profileId: String, audioId: String, text: String) async throws
}

struct WhatsAppAudioTranscriptionCacheDocument: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        text: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

final class FirestoreWhatsAppAudioTranscriptionCacheRepository: FirestoreRepository<WhatsAppAudioTranscriptionCacheDocument>, WhatsAppAudioTranscriptionCacheRepository, @unchecked Sendable {
    private let profileId: String

    init(profileId: String) {
        self.profileId = profileId
        super.init(
            entityName: "WhatsAppAudioTranscriptionCacheDocument",
            path: .profileScoped(
                scope: FirebaseProfileScope(profileId: profileId),
                collection: "whatsAppAudioTranscriptionCache"
            ),
            readSource: .cacheOnly,
            warmCacheOnInit: false
        )
    }

    func getCachedText(profileId: String, audioId: String) async throws -> String? {
        guard profileId == self.profileId else { return nil }
        guard let document = try await getById(audioId) else { return nil }
        let trimmed = document.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func saveCachedText(profileId: String, audioId: String, text: String) async throws {
        guard profileId == self.profileId else { return }

        let now = Date()
        let existing = try await getById(audioId)
        let createdAt = existing?.createdAt ?? now
        let document = WhatsAppAudioTranscriptionCacheDocument(
            id: audioId,
            text: text,
            createdAt: createdAt,
            updatedAt: now
        )
        _ = try await save(document, merge: true)
    }
}
