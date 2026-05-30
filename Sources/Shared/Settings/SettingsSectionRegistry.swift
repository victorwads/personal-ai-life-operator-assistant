import Foundation

@MainActor
final class SettingsSectionRegistry {
    private var providers: [any SettingsSectionProvider] = []

    func register(_ provider: any SettingsSectionProvider) {
        providers.append(provider)
    }

    var sections: [SettingsSectionDefinition] {
        providers
            .flatMap { $0.settingsSections() }
    }
}
