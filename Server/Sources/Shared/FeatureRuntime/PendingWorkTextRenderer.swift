import Foundation

enum WaitForEventTrigger {
    case pendingAlreadyExists
    case globalEventUnlocked
}

enum PendingWorkTextRenderer {
    static func waitForEventMessage(
        for snapshot: PendingWorkSnapshot,
        trigger: WaitForEventTrigger
    ) -> String {
        switch trigger {
        case .pendingAlreadyExists:
            return """
            event: pending work already exists.

            Pending work:
            \(renderedSections(snapshot))

            Start a new cycle and inspect active chats, issues, and client interactions.
            """
        case .globalEventUnlocked:
            guard !snapshot.isEmpty else {
                return "event: global_event unlocked. Something changed and released the global wait lock. Start a new cycle and inspect active chats, issues, and client interactions."
            }

            return """
            event: global_event unlocked and pending work is now available.

            Pending work:
            \(renderedSections(snapshot))

            Start a new cycle and inspect active chats, issues, and client interactions.
            """
        }
    }

    static func bootstrapText(for snapshot: PendingWorkSnapshot) -> String? {
        guard !snapshot.isEmpty else { return nil }

        return """
        Pending work is already available at startup.

        \(renderedSections(snapshot))
        """
    }

    private static func renderedSections(_ snapshot: PendingWorkSnapshot) -> String {
        snapshot.sections
            .map { section in
                """
                \(section.title):
                \(section.lines.map { "- \($0)" }.joined(separator: "\n"))
                """
            }
            .joined(separator: "\n\n")
    }
}
