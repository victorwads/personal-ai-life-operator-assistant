import Foundation

@MainActor
struct ClientVoicePresenceStatusProvider: ProfileRuntimeStatusProvider {
    let presenceService: ClientVoicePresenceService

    func statusItems() -> [ProfileRuntimeStatusItem] {
        let isPresent = presenceService.isPresent
        let actionTitle = isPresent ? "Pause" : "Play"

        return [
            ProfileRuntimeStatusItem(
                id: "client.voice.presence",
                title: "Client Voice",
                stateLabel: isPresent ? "Running" : "Stopped",
                detail: isPresent ? "Present" : "Absent",
                actionTitle: actionTitle,
                action: {
                    await togglePresence()
                }
            )
        ]
    }

    private func togglePresence() async {
        do {
            try await presenceService.setPresence(!presenceService.isPresent)
        } catch {
            // Keep the badge interactive without surfacing transient RTDB errors in the header.
        }
    }
}
