import Foundation

public final class FirestoreProfileRepository: FirestoreRepository<Profile>, ProfileRepository {
    public init() {
        super.init(
            entityName: "Profile",
            path: .root(collection: "AccountProfiles")
        )
    }

    public func listProfiles() async throws -> [Profile] {
        try await getAll(includeDeleted: false)
    }

    public func saveProfile(_ profile: Profile) async throws -> Profile {
        try await super.save(profile, merge: true)
    }

    public func observeProfiles(_ listener: @escaping ([Profile]) -> Void) -> FirestoreListenerToken {
        super.observe({
            Task {
                listener(try await self.listProfiles())
            }
        })
    }

    public func getProfile(id: String) async throws -> Profile? {
        try await getById(id)
    }

    public func deleteProfile(id: String) async throws {
        try await delete(id)
    }
}
