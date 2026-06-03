import Foundation

public enum FirestoreRepositoryPath: Equatable, Sendable {
    case root(collection: String)
    case profileScoped(scope: FirebaseProfileScope, collection: String)

    public var collectionPath: String {
        switch self {
        case .root(let collection):
            return collection
        case .profileScoped(let scope, let collection):
            return "\(scope.rootPath)/\(collection)"
        }
    }

    public var isValid: Bool {
        let path = collectionPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return !path.isEmpty && !path.contains("//") && !path.hasSuffix("/")
    }

    public func documentPath(for documentId: String) -> String {
        "\(collectionPath)/\(documentId)"
    }
}
