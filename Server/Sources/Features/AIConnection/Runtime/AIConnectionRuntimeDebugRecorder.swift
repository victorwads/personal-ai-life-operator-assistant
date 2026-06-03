import Foundation

struct AIConnectionRuntimeDebugRecorder {
    let maxEvents: Int

    func append(kind: String, summary: String, to state: inout AIConnectionRuntimeState) {
        state.debugEvents.append(
            AIRunDebugEventState(
                kind: kind,
                summary: summary,
                timestamp: Date()
            )
        )

        if state.debugEvents.count > maxEvents {
            state.debugEvents.removeFirst(state.debugEvents.count - maxEvents)
        }
    }
}
