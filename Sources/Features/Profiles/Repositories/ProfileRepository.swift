import Foundation

public protocol ProfileRepository {
    func listProfiles() async throws -> [Profile]
    func observeProfiles(_ listener: @escaping ([Profile]) -> Void) -> FirestoreListenerToken
    func getProfile(id: String) async throws -> Profile?
    func saveProfile(_ profile: Profile) async throws -> Profile
    func deleteProfile(id: String) async throws
}
