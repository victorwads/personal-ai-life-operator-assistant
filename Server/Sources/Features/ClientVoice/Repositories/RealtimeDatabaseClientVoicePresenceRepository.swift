import Foundation

final class RealtimeDatabaseClientVoicePresenceRepository: ClientVoicePresenceRepository {
    private let repository: FirebaseRealtimeDatabaseRepository

    init(scope: FirebaseProfileScope) {
        repository = FirebaseRealtimeDatabaseRepository(
            path: "profiles/\(scope.profileId)/clientVoice/presence/isPresent"
        )
    }

    func observePresence(_ onChange: @escaping (Bool) -> Void) -> RealtimeDatabaseListenerToken {
        repository.observeBool(onChange)
    }

    func setPresence(_ isPresent: Bool) async throws {
        try await repository.setBool(isPresent)
    }

    func getPresence() async throws -> Bool {
        try await repository.getBool()
    }
}
