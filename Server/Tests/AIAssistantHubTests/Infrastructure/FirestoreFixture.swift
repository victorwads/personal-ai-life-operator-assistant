import FirebaseFirestore
import Foundation
@testable import AIAssistantHub

struct FirestoreFixture {
    private static let defaultCollectionNames: Set<String> = [
        "AIImageExtractionCache",
        "AIResourceUsage",
        "ChatMessages",
        "Chats",
        "ClientInteractionRequests",
        "IssueTimelineItems",
        "Issues",
        "Memories",
        "SensitiveData",
        "SensitiveDataUsage",
        "SentMessages",
        "Settings",
        "Subjects"
    ]

    struct Collection {
        let name: String
        let documents: [Document]
    }

    struct Document {
        let id: String
        let data: [String: Any]
    }

    private let collections: [Collection]

    var collectionNames: Set<String> {
        Set(collections.map(\.name))
    }

    static func load(named name: String) throws -> FirestoreFixture {
        let text = try TestFixtureLoader.text(relativePath: "Firestore/\(name)")
        let fixtureObject = try JSONSerialization.jsonObject(
            with: Data(text.utf8),
            options: [.fragmentsAllowed]
        )
        return try parse(from: fixtureObject)
    }

    static func importFixture(_ scope: FirebaseProfileScope, _ name: String) async throws {
        let fixture = try load(named: name)
        try await fixture.importData(into: scope)
    }

    func importData(into scope: FirebaseProfileScope) async throws {
        let firestore = Firestore.firestore()

        for collection in collections.shuffled() {
            try await importCollection(collection, into: firestore, scope: scope)
        }
    }

    private static func parse(from fixtureObject: Any) throws -> FirestoreFixture {
        guard let root = fixtureObject as? [String: Any] else {
            throw FixtureParseError.rootMustBeDictionary
        }

        if let nestedCollections = root["collections"] as? [String: Any] {
            return try parseCollections(nestedCollections)
        }

        return try parseCollections(root)
    }

    private static func parseCollections(_ root: [String: Any]) throws -> FirestoreFixture {
        var collections: [Collection] = []

        for (name, rawDocuments) in root {
            guard defaultCollectionNames.contains(name) else {
                throw FixtureParseError.unknownCollection(name: name)
            }
            guard let rawDocuments = rawDocuments as? [Any] else {
                throw FixtureParseError.collectionMustBeArray(name: name)
            }

            let documents = try rawDocuments.enumerated().map { index, rawDocument in
                try parseDocument(rawDocument, collectionName: name, index: index)
            }

            collections.append(Collection(name: name, documents: documents))
        }

        return FirestoreFixture(collections: collections.sorted { $0.name < $1.name })
    }

    private static func parseDocument(_ rawDocument: Any, collectionName: String, index: Int) throws -> Document {
        guard let dictionary = rawDocument as? [String: Any] else {
            throw FixtureParseError.documentMustBeDictionary(collection: collectionName, index: index)
        }

        guard dictionary["_createdAt"] != nil else {
            throw FixtureParseError.documentMissingCreatedAt(collection: collectionName, index: index)
        }

        let id = try resolveDocumentID(from: dictionary, collectionName: collectionName, index: index)
        var cleaned = dictionary
        cleaned.removeValue(forKey: "id")
        cleaned.removeValue(forKey: "documentId")
        cleaned.removeValue(forKey: "_id")

        return Document(
            id: id,
            data: try normalizeDictionary(cleaned, keyPath: [])
        )
    }

    private static func resolveDocumentID(from dictionary: [String: Any], collectionName: String, index: Int) throws -> String {
        for key in ["id", "documentId", "_id"] {
            if let id = dictionary[key] as? String, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return id
            }
        }

        throw FixtureParseError.documentMissingID(collection: collectionName, index: index)
    }

    private static func normalizeDictionary(_ dictionary: [String: Any], keyPath: [String]) throws -> [String: Any] {
        var normalized: [String: Any] = [:]

        for (key, value) in dictionary {
            guard let normalizedValue = try normalizeValue(value, keyPath: keyPath + [key]) else {
                continue
            }
            normalized[key] = normalizedValue
        }

        return normalized
    }

    private static func normalizeArray(_ array: [Any], keyPath: [String]) throws -> [Any] {
        var normalized: [Any] = []

        for value in array {
            guard let normalizedValue = try normalizeValue(value, keyPath: keyPath) else {
                continue
            }
            normalized.append(normalizedValue)
        }

        return normalized
    }

    private static func normalizeValue(_ value: Any, keyPath: [String]) throws -> Any? {
        if value is NSNull {
            return nil
        }

        if let dictionary = value as? [String: Any] {
            if let date = try parseTaggedDate(dictionary) {
                return date
            }
            return try normalizeDictionary(dictionary, keyPath: keyPath)
        }

        if let array = value as? [Any] {
            return try normalizeArray(array, keyPath: keyPath)
        }

        if let string = value as? String,
           shouldParseDate(for: keyPath),
           let date = parseDate(string) {
            return date
        }

        return value
    }

    private static func shouldParseDate(for keyPath: [String]) -> Bool {
        guard let key = keyPath.last?.lowercased() else {
            return false
        }

        return key.contains("date")
            || key.contains("time")
            || key.contains("timestamp")
            || key.hasSuffix("at")
            || key.hasSuffix("until")
    }

    private static func parseTaggedDate(_ dictionary: [String: Any]) throws -> Date? {
        guard
            let type = dictionary["__type"] as? String,
            type == "date",
            let value = dictionary["value"] as? String
        else {
            return nil
        }

        guard let date = parseDate(value) else {
            throw FixtureParseError.invalidDateValue(value)
        }

        return date
    }

    private static func parseDate(_ string: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private func importCollection(_ collection: Collection, into firestore: Firestore, scope: FirebaseProfileScope) async throws {
        guard !collection.documents.isEmpty else {
            return
        }

        let batch = firestore.batch()
        let path = FirestoreRepositoryPath
            .profileScoped(scope: scope, collection: collection.name)
            .collectionPath
        let collectionReference = firestore.collection(path)

        for document in collection.documents.shuffled() {
            batch.setData(document.data, forDocument: collectionReference.document(document.id), merge: false)
        }

        try await batch.commit()
    }

    private static let dateFormatters: [ISO8601DateFormatter] = {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        return [precise, plain]
    }()
}

extension FirebaseProfileScope {
    static func testScope() -> FirebaseProfileScope {
        FirebaseProfileScope(profileId: "test-\(UUID().uuidString)")
    }

    func cleanup(collectionNames: Set<String>) async throws {
        let firestore = Firestore.firestore()
        for collectionName in collectionNames.shuffled() {
            let collection = firestore.collection(
                FirestoreRepositoryPath
                    .profileScoped(scope: self, collection: collectionName)
                    .collectionPath
            )
            let snapshot = try await collection.getDocuments()
            guard !snapshot.documents.isEmpty else {
                continue
            }

            let batch = firestore.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }

        try? await firestore.collection("AccountProfiles").document(profileId).delete()
    }
}

private enum FixtureParseError: LocalizedError {
    case rootMustBeDictionary
    case collectionMustBeArray(name: String)
    case unknownCollection(name: String)
    case documentMustBeDictionary(collection: String, index: Int)
    case documentMissingID(collection: String, index: Int)
    case documentMissingCreatedAt(collection: String, index: Int)
    case invalidDateValue(String)

    var errorDescription: String? {
        switch self {
        case .rootMustBeDictionary:
            return "Fixture root must be a dictionary."
        case let .collectionMustBeArray(name):
            return "Fixture collection '\(name)' must be an array."
        case let .unknownCollection(name):
            return "Fixture collection '\(name)' is not a valid AccountProfiles collection."
        case let .documentMustBeDictionary(collection, index):
            return "Fixture document \(index) in collection '\(collection)' must be a dictionary."
        case let .documentMissingID(collection, index):
            return "Fixture document \(index) in collection '\(collection)' is missing an id."
        case let .documentMissingCreatedAt(collection, index):
            return "Fixture document \(index) in collection '\(collection)' is missing _createdAt."
        case let .invalidDateValue(value):
            return "Fixture date value '\(value)' is invalid."
        }
    }
}
