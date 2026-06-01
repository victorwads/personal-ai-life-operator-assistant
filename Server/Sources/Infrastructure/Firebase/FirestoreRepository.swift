import Foundation
import FirebaseFirestore

public enum FirestoreRepositoryReadSource: Equatable {
    case `default`
    case cacheOnly
}

enum FirestoreRepositoryMetadataField {
    static let createdAt = "_createdAt"
    static let updatedAt = "_updatedAt"
    static let deletedAt = "_deletedAt"
}

public struct FirestoreRepositorySort: Sendable {
    let field: String
    let descending: Bool

    public init(field: String, descending: Bool = false) {
        self.field = field
        self.descending = descending
    }
}

open class FirestoreRepository<Model: PersistableModel> {
    public let entityName: String
    public let path: FirestoreRepositoryPath
    private let collection: CollectionReference

    private let firestore: Firestore
    private let dateProvider: () -> Date
    private let readSource: FirestoreRepositoryReadSource
    private let initialCacheWarmupTask: Task<Void, Never>?

    public init(
        entityName: String,
        path: FirestoreRepositoryPath,
        firestore: Firestore = .firestore(),
        readSource: FirestoreRepositoryReadSource = .cacheOnly,
        warmCacheOnInit: Bool = true,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        let collection = firestore.collection(path.collectionPath)

        self.entityName = entityName
        self.path = path
        self.firestore = firestore
        self.collection = collection
        self.dateProvider = dateProvider
        self.readSource = readSource

        if readSource == .cacheOnly && warmCacheOnInit {
            self.initialCacheWarmupTask = Task(priority: .utility) {
                do {
                    _ = try await collection.getDocuments()
                } catch {
                    print("Failed to warm Firestore cache for \(entityName): \(error.localizedDescription)")
                }
            }
        } else {
            self.initialCacheWarmupTask = nil
        }
    }
    
    private func waitForInitialCacheWarmupIfNeeded() async {
        guard readSource == .cacheOnly else { return }
        await initialCacheWarmupTask?.value
    }

    open func getAll(includeDeleted: Bool = false) async throws -> [Model] {
        try await query(includeDeleted: includeDeleted)
    }

    open func query(
        matching filters: [String: Any]? = nil,
        sortedBy sortDescriptors: [FirestoreRepositorySort] = [],
        limit: Int? = nil,
        includeDeleted: Bool = false
    ) async throws -> [Model] {
        await waitForInitialCacheWarmupIfNeeded()
        var query: Query = collection

        for (field, value) in filters ?? [:] {
            query = query.whereField(field, isEqualTo: value)
        }

        for sortDescriptor in sortDescriptors {
            query = query.order(by: sortDescriptor.field, descending: sortDescriptor.descending)
        }

        if let limit {
            query = query.limit(to: limit)
        }

        let snapshot: QuerySnapshot
        switch readSource {
        case .default:
            snapshot = try await query.getDocuments()
        case .cacheOnly:
            snapshot = try await query.getDocuments(source: .cache)
        }

        let records = try snapshot.documents.map { document in
            try decode(document: document)
        }

        if includeDeleted {
            return records.map(\.model)
        }
        return records.filter { !$0.isDeleted }.map(\.model)
    }

    open func count(matching filters: [String: Any]) async throws -> Int {
        await waitForInitialCacheWarmupIfNeeded()
        var query: Query = collection

        for (field, value) in filters {
            query = query.whereField(field, isEqualTo: value)
        }

        switch readSource {
        case .default:
            let snapshot = try await query.count.getAggregation(source: .server)
            return Int(truncating: snapshot.count)
        case .cacheOnly:
            let snapshot: QuerySnapshot = try await query.getDocuments(source: .cache)
            return snapshot.documents.count
        }
    }

    open func existingIds(matching filters: [String: Any]) async throws -> Set<String> {
        await waitForInitialCacheWarmupIfNeeded()
        var query: Query = collection
        for (field, value) in filters {
            query = query.whereField(field, isEqualTo: value)
        }

        let snapshot: QuerySnapshot = try await query.getDocuments(source: .cache)
        return Set(snapshot.documents.map(\.documentID))
    }

    open func getById(_ id: String) async throws -> Model? {
        await waitForInitialCacheWarmupIfNeeded()
        let snapshot: DocumentSnapshot
        do {
            switch readSource {
            case .default:
                snapshot = try await documentReference(for: id).getDocument()
            case .cacheOnly:
                snapshot = try await documentReference(for: id).getDocument(source: .cache)
            }
        } catch {
            if readSource == .cacheOnly {
                return nil
            }
            throw error
        }

        guard snapshot.exists else {
            return nil
        }

        let record = try decode(document: snapshot)
        guard !record.isDeleted else {
            return nil
        }
        return record.model
    }

    @discardableResult
    open func save(_ model: Model, merge: Bool = true) async throws -> Model {
        var record = model

        let documentID: String
        let isCreating: Bool
        if let existingDocumentID = record.id, !existingDocumentID.isEmpty {
            documentID = existingDocumentID
            let existingIds = try await existingIds(matching: [:])
            isCreating = existingIds.contains(existingDocumentID) == false
        } else {
            documentID = collection.document().documentID
            record.id = documentID
            isCreating = true
        }

        let document = try documentReference(for: record.id)
        let now = dateProvider()
        let payload = try makePayload(
            from: record,
            isCreating: isCreating,
            now: now
        )

        try await document.setData(payload, merge: merge)
        return record
    }

    open func saveAll(_ models: [Model]) async throws {
        guard !models.isEmpty else {
            return
        }

        let batch = firestore.batch()
        let now = dateProvider()
        var existingIds = try await existingIds(matching: [:])

        for model in models {
            var record = model

            let documentID: String
            let isCreating: Bool
            if let existingDocumentID = record.id, !existingDocumentID.isEmpty {
                documentID = existingDocumentID
                isCreating = existingIds.contains(existingDocumentID) == false
            } else {
                documentID = collection.document().documentID
                record.id = documentID
                isCreating = true
                existingIds.insert(documentID)
            }

            let payload = try makePayload(
                from: record,
                isCreating: isCreating,
                now: now
            )

            let document = collection.document(documentID)
            batch.setData(payload, forDocument: document, merge: true)
        }

        try await batch.commit()
    }

    open func updateAll(ids: [String], data: [String: Any]) async throws {
        guard !ids.isEmpty else {
            return
        }

        let payload = makeUpdatePayload(from: data)
        let batch = firestore.batch()

        for id in ids {
            let document = try documentReference(for: id)
            batch.updateData(payload, forDocument: document)
        }

        try await batch.commit()
    }

    open func delete(_ id: String, soft: Bool = false) async throws {
        guard !id.isEmpty else {
            throw FirestoreRepositoryError.missingDocumentId
        }

        let reference = try documentReference(for: id)

        if soft {
            let now = dateProvider()
            try await reference.updateData([
                FirestoreRepositoryMetadataField.deletedAt: now,
                FirestoreRepositoryMetadataField.updatedAt: now
            ])
        } else {
            try await reference.delete()
        }
    }

    open func observe(_ listener: @escaping ([Model]) -> Void) -> FirestoreListenerToken {
        let registration = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            guard let snapshot else {
                if let error {
                    print("Failed to observe \(self.entityName): \(error.localizedDescription)")
                }
                listener([])
                return
            }

            do {
                let records = try snapshot.documents.map { document in
                    try self.decode(document: document)
                }
                listener(records.filter { !$0.isDeleted }.map(\.model))
            } catch {
                print("Failed to decode \(self.entityName) snapshot: \(error.localizedDescription)")
                listener([])
            }
        }

        return FirestoreListenerToken {
            registration.remove()
        }
    }

    private func documentReference(for id: String?) throws -> DocumentReference {
        guard path.isValid else {
            throw FirestoreRepositoryError.invalidPath
        }
        guard let id, !id.isEmpty else {
            throw FirestoreRepositoryError.missingDocumentId
        }
        return firestore.collection(path.collectionPath).document(id)
    }

    private func decode(document: QueryDocumentSnapshot) throws -> (model: Model, isDeleted: Bool) {
        do {
            let model = try document.data(as: Model.self)
            return (model: model, isDeleted: isDeleted(from: document.data()))
        } catch {
            throw FirestoreRepositoryError.decodingFailed(entity: entityName)
        }
    }

    private func decode(document: DocumentSnapshot) throws -> (model: Model, isDeleted: Bool) {
        do {
            let model = try document.data(as: Model.self)
            let data = document.data() ?? [:]
            return (model: model, isDeleted: isDeleted(from: data))
        } catch {
            throw FirestoreRepositoryError.decodingFailed(entity: entityName)
        }
    }

    private func makePayload(
        from model: Model,
        isCreating: Bool,
        now: Date
    ) throws -> [String: Any] {
        var payload = try Firestore.Encoder().encode(model)
        payload = removeNilFields(from: payload)

        if isCreating {
            payload[FirestoreRepositoryMetadataField.createdAt] = now
            payload[FirestoreRepositoryMetadataField.updatedAt] = now
            payload.removeValue(forKey: FirestoreRepositoryMetadataField.deletedAt)
            return payload
        }

        payload.removeValue(forKey: FirestoreRepositoryMetadataField.createdAt)
        payload[FirestoreRepositoryMetadataField.updatedAt] = now
        payload.removeValue(forKey: FirestoreRepositoryMetadataField.deletedAt)
        return payload
    }

    private func makeUpdatePayload(from data: [String: Any]) -> [String: Any] {
        var payload = removeNilFields(from: data)
        payload.removeValue(forKey: FirestoreRepositoryMetadataField.createdAt)
        payload[FirestoreRepositoryMetadataField.updatedAt] = dateProvider()
        payload.removeValue(forKey: FirestoreRepositoryMetadataField.deletedAt)
        return payload
    }

    private func removeNilFields(from data: [String: Any]) -> [String: Any] {
        var cleaned: [String: Any] = [:]
        for (key, value) in data {
            if let normalized = normalizeFirestoreValue(value) {
                cleaned[key] = normalized
            }
        }
        return cleaned
    }

    private func normalizeFirestoreValue(_ value: Any) -> Any? {
        if value is NSNull {
            return nil
        }

        if let dictionary = value as? [String: Any] {
            return removeNilFields(from: dictionary)
        }

        if let array = value as? [Any] {
            return array.compactMap { normalizeFirestoreValue($0) }
        }

        return value
    }

    private func isDeleted(from data: [String: Any]) -> Bool {
        guard let value = data[FirestoreRepositoryMetadataField.deletedAt] else {
            return false
        }

        if value is NSNull {
            return false
        }

        return true
    }
}
