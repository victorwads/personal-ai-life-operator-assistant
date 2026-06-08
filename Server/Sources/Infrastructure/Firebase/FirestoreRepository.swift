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

        let records = snapshot.documents.compactMap { document in
            decodeIfPossible(document: document)
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
            return nil
        }

        guard snapshot.exists else {
            return nil
        }

        guard let record = decodeIfPossible(document: snapshot) else {
            return nil
        }
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

    open func update(id: String, data: [String: Any]) async throws {
        guard !id.isEmpty else {
            throw FirestoreRepositoryError.missingDocumentId
        }

        let payload = makeUpdatePayload(from: data)
        let document = try documentReference(for: id)
        try await document.updateData(payload)
    }

    open func increment(id: String, fields: [String: Int]) async throws {
        guard !id.isEmpty else {
            throw FirestoreRepositoryError.missingDocumentId
        }

        var payload: [String: Any] = [:]
        for (field, value) in fields where value != 0 {
            payload[field] = FieldValue.increment(Int64(value))
        }

        guard !payload.isEmpty else { return }

        payload[FirestoreRepositoryMetadataField.updatedAt] = dateProvider()

        let document = try documentReference(for: id)
        try await document.setData(payload, merge: true)
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

    open func deleteAll(ids: [String], soft: Bool = false) async throws {
        let documentIds = ids.filter { !$0.isEmpty }
        guard !documentIds.isEmpty else {
            return
        }

        let now = dateProvider()
        for chunk in documentIds.chunked(into: 450) {
            let batch = firestore.batch()
            for id in chunk {
                let reference = try documentReference(for: id)
                if soft {
                    batch.updateData([
                        FirestoreRepositoryMetadataField.deletedAt: now,
                        FirestoreRepositoryMetadataField.updatedAt: now
                    ], forDocument: reference)
                } else {
                    batch.deleteDocument(reference)
                }
            }
            try await batch.commit()
        }
    }

    open func observe(_ listener: @escaping () -> Void) -> FirestoreListenerToken {
        let registration = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            listener()
        }

        return FirestoreListenerToken {
            registration.remove()
        }
    }

    open func observe(
        matching filters: [String: Any]? = nil,
        sortedBy sortDescriptors: [FirestoreRepositorySort] = [],
        limit: Int? = nil,
        listener: @escaping () -> Void
    ) -> FirestoreListenerToken {
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

        let registration = query.addSnapshotListener { _, _ in
            listener()
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
            logDecodingFailure(documentId: document.documentID, data: document.data(), error: error)
            throw FirestoreRepositoryError.decodingFailed(entity: entityName)
        }
    }

    private func decode(document: DocumentSnapshot) throws -> (model: Model, isDeleted: Bool) {
        do {
            let model = try document.data(as: Model.self)
            let data = document.data() ?? [:]
            return (model: model, isDeleted: isDeleted(from: data))
        } catch {
            logDecodingFailure(documentId: document.documentID, data: document.data() ?? [:], error: error)
            throw FirestoreRepositoryError.decodingFailed(entity: entityName)
        }
    }

    private func decodeIfPossible(document: QueryDocumentSnapshot) -> (model: Model, isDeleted: Bool)? {
        do {
            return try decode(document: document)
        } catch {
            return nil
        }
    }

    private func decodeIfPossible(document: DocumentSnapshot) -> (model: Model, isDeleted: Bool)? {
        do {
            return try decode(document: document)
        } catch {
            return nil
        }
    }

    private func logDecodingFailure(
        documentId: String,
        data: [String: Any],
        error: Error
    ) {
        let payload = serializedLogPayload(from: data)
        print("FirestoreRepository decode failure for \(entityName) document \(documentId): \(error.localizedDescription). Payload: \(payload)")
    }

    private func serializedLogPayload(from data: [String: Any]) -> String {
        let normalized = normalizeLogValue(data)
        guard JSONSerialization.isValidJSONObject(normalized),
              let jsonData = try? JSONSerialization.data(withJSONObject: normalized, options: [.prettyPrinted]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return String(describing: data)
        }
        return jsonString
    }

    private func normalizeLogValue(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues(normalizeLogValue)
        }

        if let array = value as? [Any] {
            return array.map(normalizeLogValue)
        }

        if let date = value as? Date {
            return ISO8601DateFormatter().string(from: date)
        }

        if value is NSNull || value is String || value is NSNumber {
            return value
        }

        return String(describing: value)
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
        var payload = normalizeUpdateFields(from: data)
        payload.removeValue(forKey: FirestoreRepositoryMetadataField.createdAt)
        payload[FirestoreRepositoryMetadataField.updatedAt] = dateProvider()
        payload.removeValue(forKey: FirestoreRepositoryMetadataField.deletedAt)
        return payload
    }

    private func normalizeUpdateFields(from data: [String: Any]) -> [String: Any] {
        var cleaned: [String: Any] = [:]
        for (key, value) in data {
            if value is NSNull {
                cleaned[key] = FieldValue.delete()
                continue
            }

            if let normalized = normalizeFirestoreValue(value) {
                cleaned[key] = normalized
            }
        }
        return cleaned
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

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        return stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
