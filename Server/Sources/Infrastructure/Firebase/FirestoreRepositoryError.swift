import Foundation

public enum FirestoreRepositoryError: Error, Equatable {
    case missingDocumentId
    case documentNotFound
    case decodingFailed(entity: String)
    case encodingFailed(entity: String)
    case invalidPath
    case firestoreError(message: String)
}

extension FirestoreRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingDocumentId:
            return "The Firestore document identifier is missing."
        case .documentNotFound:
            return "The requested Firestore document was not found."
        case .decodingFailed(let entity):
            return "Failed to decode \(entity) from Firestore data."
        case .encodingFailed(let entity):
            return "Failed to encode \(entity) for Firestore."
        case .invalidPath:
            return "The Firestore repository path is invalid."
        case .firestoreError(let message):
            return message
        }
    }
}
