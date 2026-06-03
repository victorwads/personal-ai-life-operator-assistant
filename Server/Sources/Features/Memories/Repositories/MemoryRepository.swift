import Foundation

final class FirestoreMemoryRepository: FirestoreRepository<Memory> {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "Memory",
            path: .profileScoped(scope: scope, collection: "Memories")
        )
    }
}
