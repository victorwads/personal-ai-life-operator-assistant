import Combine
import Foundation

extension AppModel {
    func loadMCPSendMessagePrefixSetting() {
        mcpSendMessagePrefix = UserDefaults.standard.string(forKey: mcpSendMessagePrefixDefaultsKey) ?? ""

        $mcpSendMessagePrefix
            .dropFirst()
            .sink { [weak self] value in
                guard let self else { return }
                UserDefaults.standard.set(value, forKey: self.mcpSendMessagePrefixDefaultsKey)
            }
            .store(in: &cancellables)
    }

    func applyMCPSendMessagePrefixIfNeeded(_ text: String) -> String {
        let prefix = mcpSendMessagePrefix
        guard !prefix.isEmpty else { return text }
        return prefix + text
    }
}

