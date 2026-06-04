import Foundation

@MainActor
struct ClientVoicePresenceStatusProvider: ProfileRuntimeStatusProvider {
    let presenceService: ClientVoicePresenceService

    func statusItems() -> [ProfileRuntimeStatusItem] {
        let isPresent = presenceService.isPresent
        let actionTitle = isPresent ? "Set Absent" : "Set Present"

        return [
            ProfileRuntimeStatusItem(
                id: "client.voice.presence",
                title: "Client Presence",
                stateLabel: isPresent ? "running" : "Absent",
                detail: isPresent ? "Client is present" : "Client is absent",
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
