import Foundation
import FirebaseFirestore

open class FirebaseRepository<Model: PersistableModel> {
    public let entityName: String
    public let path: FirebaseRepositoryPath
    public let collection: CollectionReference

    private let firestore: Firestore
    private let dateProvider: () -> Date

    private var cache: [String: Model] = [:]

    public init(
        entityName: String,
        path: FirebaseRepositoryPath,
        firestore: Firestore = .firestore(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.entityName = entityName
        self.path = path
        self.firestore = firestore
        self.collection = firestore.collection(path.collectionPath)
        self.dateProvider = dateProvider
    }

    open func getAll(includeDeleted: Bool = false) async throws -> [Model] {
        let snapshot = try await collection.getDocuments()
        let models = try snapshot.documents.map { try decode(document: $0) }
        mergeCache(models)
        return includeDeleted ? models : models.filter { $0.deletedAt == nil }
    }

    open func getById(_ id: String) async throws -> Model? {
        let snapshot = try await documentReference(for: id).getDocument()
        guard snapshot.exists else {
            return nil
        }

        let model = try decode(document: snapshot)
        cache[model.id ?? snapshot.documentID] = model
        return model
    }

    open func getLocalById(_ id: String) -> Model? {
        cache[id]
    }

    @discardableResult
    open func save(_ model: Model, merge: Bool = true) async throws -> Model {
        var record = model
        let isCreating = record.id?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true

        if isCreating {
            record.id = collection.document().documentID
            record.createdAt = dateProvider()
        }

        record.updatedAt = dateProvider()

        let document = try documentReference(for: record.id)
        try await document.setData(from: record, merge: merge)
        cache[document.documentID] = record
        return record
    }

    open func saveAll(_ models: [Model]) async throws {
        guard !models.isEmpty else {
            return
        }

        let batch = firestore.batch()
        var persistedModels: [Model] = []

        for model in models {
            var record = model
            if record.id?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                record.id = collection.document().documentID
                record.createdAt = dateProvider()
            }

            record.updatedAt = dateProvider()
            guard let documentID = record.id, !documentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FirestoreRepositoryError.missingDocumentId
            }
            let document = collection.document(documentID)
            try batch.setData(from: record, forDocument: document, merge: true)
            persistedModels.append(record)
        }

        try await batch.commit()
        mergeCache(persistedModels)
    }

    open func delete(_ id: String, soft: Bool = false) async throws {
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
        let registration = collection.addSnapshotListener { [weak self] snapshot, _ in
            guard let self else { return }

            guard let snapshot else {
                listener(self.visibleCachedModels())
                return
            }

            do {
                let models = try snapshot.documents.map { try self.decode(document: $0) }
                self.mergeCache(models)
                listener(models.filter { $0.deletedAt == nil })
            } catch {
                listener(self.visibleCachedModels())
            }
        }

        return FirestoreListenerToken {
            registration.remove()
        }
    }

    open func clearCache() {
        cache.removeAll()
    }

    private func documentReference(for id: String?) throws -> DocumentReference {
        guard path.isValid else {
            throw FirestoreRepositoryError.invalidPath
        }
        guard let id, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FirestoreRepositoryError.missingDocumentId
        }
        return firestore.collection(path.collectionPath).document(id)
    }

    private func decode(document: QueryDocumentSnapshot) throws -> Model {
        do {
            return try document.data(as: Model.self)
        } catch {
            throw FirestoreRepositoryError.decodingFailed(entity: entityName)
        }
    }

    private func decode(document: DocumentSnapshot) throws -> Model {
        do {
            return try document.data(as: Model.self)
        } catch {
            throw FirestoreRepositoryError.decodingFailed(entity: entityName)
        }
    }

    private func mergeCache(_ models: [Model]) {
        for model in models {
            guard let id = model.id, !id.isEmpty else {
                continue
            }
            cache[id] = model
        }
    }

    private func visibleCachedModels() -> [Model] {
        cache.values
            .filter { $0.deletedAt == nil }
            .sorted {
                ($0.id ?? "") < ($1.id ?? "")
            }
    }

}
