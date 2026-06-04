import SwiftUI

@MainActor
struct ClientVoiceSettingsSectionProvider: SettingsSectionProvider {
    let wrapper: ClientVoiceSettingsWrapper

    func settingsSections() -> [SettingsSectionDefinition] {
        [
            SettingsSectionDefinition(
                scopeName: ClientVoiceSettingsWrapper.scopeName,
                title: "Client Voice"
            ) {
                AnyView(
                    ClientVoiceSettingsView(wrapper: wrapper)
                )
            }
        ]
    }
}
