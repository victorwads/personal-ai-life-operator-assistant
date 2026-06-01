import Foundation

@MainActor
struct VoiceClientPresenceRuntimeStatusProvider: ProfileRuntimeStatusProvider {
    let presenceService: VoiceClientPresenceService

    func statusItems() -> [ProfileRuntimeStatusItem] {
        let isPresent = presenceService.presence == .present
        let actionTitle = isPresent ? "Pause" : "Play"

        return [
            ProfileRuntimeStatusItem(
                id: "voice.client.presence.status",
                title: "Client Presence",
                stateLabel: isPresent ? "Running" : "Stopped",
                detail: isPresent ? "Present" : "Absent",
                actionTitle: actionTitle,
                action: {
                    if isPresent {
                        await presenceService.stop()
                    } else {
                        await presenceService.start()
                    }
                }
            )
        ]
    }
}
