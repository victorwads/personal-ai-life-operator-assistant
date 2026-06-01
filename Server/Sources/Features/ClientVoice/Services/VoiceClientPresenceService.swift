import Foundation

@MainActor
final class VoiceClientPresenceService: ProfileRuntimeService {
    let id: String
    let title: String

    private(set) var presence: ClientPresenceState = .absent
    private(set) var state: ProfileRuntimeServiceState = .stopped

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    func start() async {
        guard presence != .present else { return }
        presence = .present
        state = .running
    }

    func stop() async {
        guard presence != .absent else { return }
        presence = .absent
        state = .stopped
    }
}
