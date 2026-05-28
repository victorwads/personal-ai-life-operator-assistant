import Foundation
import FirebaseFirestore

public final class FirestoreProfileRepository: FirebaseRepository<Profile>, ProfileRepository {
    public init(firestore: Firestore = .firestore()) {
        super.init(
            entityName: "Profile",
            path: .root(collection: "AccountProfiles"),
            firestore: firestore
        )
    }

    public func listProfiles() async throws -> [Profile] {
        try await getAll(includeDeleted: false)
    }

    public func saveProfile(_ profile: Profile) async throws -> Profile {
        try await super.save(profile, merge: true)
    }

    public func observeProfiles(_ listener: @escaping ([Profile]) -> Void) -> FirestoreListenerToken {
        super.observe(listener)
    }

    public func getProfile(id: String) async throws -> Profile? {
        try await getById(id)
    }

    public func deleteProfile(id: String) async throws {
        try await delete(id)
    }
}
