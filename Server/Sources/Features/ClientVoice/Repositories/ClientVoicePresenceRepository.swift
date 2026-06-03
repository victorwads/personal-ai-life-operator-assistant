protocol ClientVoicePresenceRepository: AnyObject {
    func observePresence(_ onChange: @escaping (Bool) -> Void) -> RealtimeDatabaseListenerToken
    func setPresence(_ isPresent: Bool) async throws
    func getPresence() async throws -> Bool
}
