import FirebaseFirestore
import Foundation

enum FirestoreCacheResetCoordinator {
    static func clearActivePersistence() async throws {
        let firestore = Firestore.firestore()
        try await firestore.terminate()
        try await firestore.clearPersistence()
    }
}
