import Foundation

extension AppModel {
    func dumpWhatsAppSnapshot() {
        let trustedNow = accessibility.isTrusted(prompt: false)
        accessibilityTrusted = trustedNow

        guard trustedNow else {
            appendLog("Cannot inspect WhatsApp before Accessibility permission is granted to this exact app binary.", level: .warning)
            appendLog(accessibility.currentAppIdentityDescription(), level: .warning)
            appendLog("When running from Xcode, macOS may require granting permission to the built app in DerivedData and then relaunching it.", level: .warning)
            return
        }

        do {
            let snapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
            writeDebugArtifacts(snapshot: snapshot, screenState: parser.parse(snapshot: snapshot, messageLimit: 10), prefix: "manual-dump")
            appendLog("Captured WhatsApp Accessibility snapshot.")
            appendLog("Wrote debug files to \(debugDirectory.path).")
            appendLog(snapshot.prettyDescription)
        } catch {
            appendLog("Failed to capture WhatsApp snapshot: \(error.localizedDescription)", level: .error)
        }
    }

    func captureDebugSnapshot() {
        guard prepareForWhatsAppInspection() else {
            return
        }

        do {
            let snapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
            debugSnapshot = snapshot
            debugNodePath = []
            appendLog("Captured debug snapshot for tree view.")
        } catch {
            appendLog("Failed to capture debug snapshot: \(error.localizedDescription)", level: .error)
        }
    }

    func writeDebugArtifacts(snapshot: WhatsAppSnapshot, screenState: WhatsAppScreenState, prefix: String) {
        do {
            try FileManager.default.createDirectory(at: debugDirectory, withIntermediateDirectories: true)
            try snapshot.prettyDescription.write(to: debugDirectory.appendingPathComponent("latest-snapshot.txt"), atomically: true, encoding: .utf8)
            try parser.debugReport(snapshot: snapshot).write(to: debugDirectory.appendingPathComponent("latest-parser-report.txt"), atomically: true, encoding: .utf8)
            try conversationReport(screenState).write(to: debugDirectory.appendingPathComponent("latest-state.txt"), atomically: true, encoding: .utf8)

            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            try parser.debugReport(snapshot: snapshot).write(to: debugDirectory.appendingPathComponent("\(timestamp)-\(prefix)-parser-report.txt"), atomically: true, encoding: .utf8)
        } catch {
            appendLog("Failed to write parser debug artifacts: \(error.localizedDescription)", level: .warning)
        }
    }

    private func conversationReport(_ screenState: WhatsAppScreenState) -> String {
        let conversations = screenState.conversations.map { conversation in
            "- \(conversation.name) | unread=\(conversation.unreadCount) | date=\(conversation.lastMessageAtText ?? "nil") | preview=\(conversation.lastMessagePreview ?? "nil")"
        }.joined(separator: "\n")

        let messages = screenState.messages.map { message in
            "- \(message.direction.rawValue) \(message.status.rawValue): \(message.text ?? message.rawAccessibilityText)"
        }.joined(separator: "\n")

        return """
        Conversations:
        \(conversations.isEmpty ? "- none" : conversations)

        Messages:
        \(messages.isEmpty ? "- none" : messages)
        """
    }
}
