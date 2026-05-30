import Foundation

@MainActor
struct SettingsContext {
    let store: SettingsStore
    let sectionRegistry: SettingsSectionRegistry
}
