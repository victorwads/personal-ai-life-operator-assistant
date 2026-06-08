import Foundation

protocol AIImageExtractionCacheRepository: Sendable {
    func getCachedText(profileId: String, imageId: String) async throws -> String?
    func saveCachedText(profileId: String, imageId: String, text: String) async throws
}

struct AIImageExtractionCacheDocument: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var imageId: String
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        imageId: String,
        text: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.imageId = imageId
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

final class FirestoreAIImageExtractionCacheRepository: FirestoreRepository<AIImageExtractionCacheDocument>, AIImageExtractionCacheRepository {
    private let profileId: String

    init(profileId: String) {
        self.profileId = profileId
        super.init(
            entityName: "ImageExtractionCaches",
            path: .profileScoped(scope: FirebaseProfileScope(profileId: profileId), collection: "ImageExtractionCaches"),
            readSource: .cacheOnly,
            warmCacheOnInit: false
        )
    }

    func getCachedText(profileId: String, imageId: String) async throws -> String? {
        guard profileId == self.profileId else { return nil }
        guard let document = try await getById(imageId) else { return nil }
        let trimmed = document.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func saveCachedText(profileId: String, imageId: String, text: String) async throws {
        guard profileId == self.profileId else { return }

        let now = Date()
        let existing = try await getById(imageId)
        let createdAt = existing?.createdAt ?? now
        let document = AIImageExtractionCacheDocument(
            id: imageId,
            imageId: imageId,
            text: text,
            createdAt: createdAt,
            updatedAt: now
        )
        _ = try await save(document, merge: true)
    }
}
