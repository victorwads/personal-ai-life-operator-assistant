import Foundation

final class FirestoreMemoryRepository: FirestoreRepository<Memory> {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "Memory",
            path: .profileScoped(scope: scope, collection: "Memories")
        )
    }

    func findByKey(_ key: String) async throws -> Memory? {
        try await query(
            matching: ["key": key],
            sortedBy: [FirestoreRepositorySort(field: FirestoreRepositoryMetadataField.createdAt)],
            limit: 1
        ).first
    }

    @discardableResult
    func saveByKey(key: String, value: String) async throws -> Memory {
        let existingMemory = try await findByKey(key)

        return try await save(
            Memory(
                id: existingMemory?.id,
                key: key,
                value: value
            )
        )
    }
}
