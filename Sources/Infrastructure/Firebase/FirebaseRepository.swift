import Foundation
import FirebaseFirestore

open class FirebaseRepository<Model: PersistableModel> {
    public let entityName: String
    public let path: FirebaseRepositoryPath

    private let firestore: Firestore
    private let mapper: FirestoreCodableMapper
    private let dateProvider: () -> Date
    private let identifierProvider: () -> String

    private var cache: [String: Model] = [:]

    public init(
        entityName: String,
        path: FirebaseRepositoryPath,
        firestore: Firestore = .firestore(),
        mapper: FirestoreCodableMapper = FirestoreCodableMapper(),
        dateProvider: @escaping () -> Date = Date.init,
        identifierProvider: @escaping () -> String = { UUID().uuidString }
    ) {
        self.entityName = entityName
        self.path = path
        self.firestore = firestore
        self.mapper = mapper
        self.dateProvider = dateProvider
        self.identifierProvider = identifierProvider
    }

    open func getAll(includeDeleted: Bool = false) async throws -> [Model] {
        let snapshot = try await collectionReference().getDocuments()
        let models = try snapshot.documents.map { try decode($0.data(), documentId: $0.documentID) }
        mergeCache(models)
        return includeDeleted ? models : models.filter { $0.deletedAt == nil }
    }

    open func getById(_ id: String) async throws -> Model? {
        let snapshot = try await documentReference(for: id).getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }

        let model = try decode(data, documentId: snapshot.documentID)
        cache[model.id] = model
        return model
    }

    open func getLocalById(_ id: String) -> Model? {
        cache[id]
    }

    @discardableResult
    open func save(_ model: Model, merge: Bool = true) async throws -> Model {
        var record = model
        let isCreating = record.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if isCreating {
            record.id = identifierProvider()
            record.createdAt = dateProvider()
        }

        record.updatedAt = dateProvider()

        let data = try encode(record)
        try await documentReference(for: record.id).setData(data, merge: merge)
        cache[record.id] = record
        return record
    }

    open func saveAll(_ models: [Model]) async throws {
        guard !models.isEmpty else {
            return
        }

        let batch = firestore.batch()
        var persistedModels: [Model] = []
        let collection = try collectionReference()

        for model in models {
            var record = model
            if record.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                record.id = identifierProvider()
                record.createdAt = dateProvider()
            }

            record.updatedAt = dateProvider()
            let data = try encode(record)
            batch.setData(data, forDocument: collection.document(record.id), merge: true)
            persistedModels.append(record)
        }

        try await batch.commit()
        mergeCache(persistedModels)
    }

    open func delete(_ id: String, soft: Bool = true) async throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FirestoreRepositoryError.missingDocumentId
        }

        let reference = try documentReference(for: id)

        if soft {
            let now = dateProvider()
            try await reference.updateData([
                "deletedAt": now,
                "updatedAt": now
            ])

            if var cachedModel = cache[id] {
                cachedModel.deletedAt = now
                cachedModel.updatedAt = now
                cache[id] = cachedModel
            }
        } else {
            try await reference.delete()
            cache.removeValue(forKey: id)
        }
    }

    open func observe(_ listener: @escaping ([Model]) -> Void) -> FirestoreListenerToken {
        guard let collection = try? collectionReference() else {
            return FirestoreListenerToken {}
        }

        let registration = collection.addSnapshotListener { [weak self] snapshot, _ in
            guard let self else { return }

            guard let snapshot else {
                listener(self.cache.values.filter { $0.deletedAt == nil }.sorted { $0.id < $1.id })
                return
            }

            do {
                let models = try snapshot.documents.map { try self.decode($0.data(), documentId: $0.documentID) }
                self.mergeCache(models)
                listener(models.filter { $0.deletedAt == nil })
            } catch {
                listener(self.cache.values.filter { $0.deletedAt == nil }.sorted { $0.id < $1.id })
            }
        }

        return FirestoreListenerToken {
            registration.remove()
        }
    }

    open func clearCache() {
        cache.removeAll()
    }

    private func collectionReference() throws -> CollectionReference {
        guard path.isValid else {
            throw FirestoreRepositoryError.invalidPath
        }
        return firestore.collection(path.collectionPath)
    }

    private func documentReference(for id: String) throws -> DocumentReference {
        guard path.isValid else {
            throw FirestoreRepositoryError.invalidPath
        }
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FirestoreRepositoryError.missingDocumentId
        }
        return firestore.collection(path.collectionPath).document(id)
    }

    private func encode(_ model: Model) throws -> [String: Any] {
        do {
            return try mapper.encode(model, entityName: entityName)
        } catch {
            throw FirestoreRepositoryError.encodingFailed(entity: entityName)
        }
    }

    private func decode(_ data: [String: Any], documentId: String?) throws -> Model {
        do {
            return try mapper.decode(Model.self, from: data, documentId: documentId, entityName: entityName)
        } catch {
            throw FirestoreRepositoryError.decodingFailed(entity: entityName)
        }
    }

    private func mergeCache(_ models: [Model]) {
        for model in models {
            cache[model.id] = model
        }
    }

}
