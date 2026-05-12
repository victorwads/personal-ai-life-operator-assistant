import Combine
import Foundation

extension AppModel {
    static let defaultAssistantInstructions = """
    You can control WhatsApp through the MCP tools:
    - list_chats: list mapped chats
    - get_recent_messages: load recent messages for a chat
    - send_message: send a message through Accessibility
    - wait_for_message: wait for the next message

    If you need to notify the user, use:
    - speak: announce something out loud
    - ask_user: ask a question out loud and wait for a spoken response

    Use get_instructions to fetch the latest instructions stored in the app UI.
    """

    func loadAssistantInstructions() {
        assistantInstructions = UserDefaults.standard.string(forKey: assistantInstructionsDefaultsKey) ?? Self.defaultAssistantInstructions
        bindAssistantInstructionsPersistence()
    }

    private func bindAssistantInstructionsPersistence() {
        $assistantInstructions
            .dropFirst()
            .sink { [weak self] value in
                guard let self else { return }
                UserDefaults.standard.set(value, forKey: self.assistantInstructionsDefaultsKey)
            }
            .store(in: &cancellables)
    }
}

