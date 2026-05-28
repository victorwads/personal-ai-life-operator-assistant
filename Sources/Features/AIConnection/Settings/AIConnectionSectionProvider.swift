import SwiftUI

@MainActor
struct AIConnectionSettingsSectionProvider: SettingsSectionProvider {
    let wrapper: AIConnectionSettingsWrapper

    func settingsSections() -> [SettingsSectionDefinition] {
        [
            SettingsSectionDefinition(
                scopeName: "aiConnection",
                title: "AI Connection"
            ) {
                AnyView(
                    AIConnectionSettingsView(wrapper: wrapper)
                )
            }
        ]
    }
}
