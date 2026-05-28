import FirebaseFirestore
import Foundation

final class FirestoreSettingsRepository: SettingsRepository {
    private let firestore: Firestore
    private let scope: FirebaseProfileScope

    init(scope: FirebaseProfileScope, firestore: Firestore = .firestore()) {
        self.scope = scope
        self.firestore = firestore
    }

    func loadScope(_ scopeName: String) async throws -> SettingsDocument {
        let snapshot = try await documentReference(scopeName).getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            return SettingsDocument(scopeName: scopeName)
        }

        return SettingsDocument(scopeName: scopeName, values: decodeValues(data))
    }

    func loadAllScopes() async throws -> [SettingsDocument] {
        let snapshot = try await collectionReference.getDocuments()
        return snapshot.documents.map { document in
            SettingsDocument(
                scopeName: document.documentID,
                values: Self.decodeValues(document.data())
            )
        }
    }

    func saveScope(_ scopeName: String, values: [String: String]) async throws {
        try await documentReference(scopeName).setData(values, merge: false)
    }

    func getValue(scopeName: String, key: String) async throws -> String? {
        try await loadScope(scopeName).values[key]
    }

    func setValue(scopeName: String, key: String, value: String) async throws {
        try await documentReference(scopeName).setData([key: value], merge: true)
    }

    func deleteValue(scopeName: String, key: String) async throws {
        try await documentReference(scopeName).updateData([key: FieldValue.delete()])
    }

    func observeScope(_ scopeName: String, listener: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken {
        let registration = documentReference(scopeName).addSnapshotListener { snapshot, _ in
            guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                listener(SettingsDocument(scopeName: scopeName))
                return
            }

            listener(SettingsDocument(scopeName: scopeName, values: Self.decodeValues(data)))
        }

        return FirestoreListenerToken {
            registration.remove()
        }
    }

    func observeAllScopes(_ listener: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken {
        let registration = collectionReference.addSnapshotListener { snapshot, _ in
            guard let snapshot else {
                listener([])
                return
            }

            listener(snapshot.documents.map { document in
                SettingsDocument(
                    scopeName: document.documentID,
                    values: Self.decodeValues(document.data())
                )
            })
        }

        return FirestoreListenerToken {
            registration.remove()
        }
    }

    private func documentReference(_ scopeName: String) -> DocumentReference {
        collectionReference.document(scopeName)
    }

    private var collectionReference: CollectionReference {
        // Firestore collection names are PascalCase by convention in this repo.
        firestore.collection("\(scope.rootPath)/Settings")
    }

    private func decodeValues(_ data: [String: Any]) -> [String: String] {
        Self.decodeValues(data)
    }

    private static func decodeValues(_ data: [String: Any]) -> [String: String] {
        data.compactMapValues { $0 as? String }
    }
}
