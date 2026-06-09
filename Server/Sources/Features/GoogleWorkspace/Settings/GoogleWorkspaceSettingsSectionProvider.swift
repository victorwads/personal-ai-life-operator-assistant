import SwiftUI

@MainActor
struct GoogleWorkspaceSettingsSectionProvider: SettingsSectionProvider {
    let wrapper: GoogleWorkspaceSettingsWrapper
    let authStatusProvider: @MainActor () -> GoogleWorkspaceAuthState

    func settingsSections() -> [SettingsSectionDefinition] {
        [
            SettingsSectionDefinition(
                scopeName: "googleWorkspace",
                title: "Google Workspace"
            ) {
                AnyView(
                    GoogleWorkspaceSettingsView(
                        wrapper: wrapper,
                        authStatusProvider: authStatusProvider
                    )
                )
            }
        ]
    }
}
