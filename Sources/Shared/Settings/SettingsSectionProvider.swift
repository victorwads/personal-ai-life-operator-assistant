import Foundation

@MainActor
protocol SettingsSectionProvider {
    func settingsSections() -> [SettingsSectionDefinition]
}
