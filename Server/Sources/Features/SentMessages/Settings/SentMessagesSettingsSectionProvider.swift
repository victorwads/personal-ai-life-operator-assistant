import SwiftUI

@MainActor
struct SentMessagesSettingsSectionProvider: SettingsSectionProvider {
    let wrapper: SentMessagesSettingsWrapper

    func settingsSections() -> [SettingsSectionDefinition] {
        [
            SettingsSectionDefinition(
                scopeName: "sentMessages",
                title: "Sent Messages"
            ) {
                AnyView(
                    SentMessagesSettingsView(wrapper: wrapper)
                )
            }
        ]
    }
}
