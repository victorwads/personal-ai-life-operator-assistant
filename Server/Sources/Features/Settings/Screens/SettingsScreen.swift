import SwiftUI

struct SettingsScreen: View {
    let settingsSectionRegistry: SettingsSectionRegistry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DSFeatureHeader(title: "Settings")

                if let settingsSectionRegistry {
                    let sections = settingsSectionRegistry.sections

                    if sections.isEmpty {
                        emptyState(message: "No settings sections registered for this profile.")
                    } else {
                        ForEach(sections) { section in
                            DSTitledSection(title: section.title) {
                                section.makeView()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else {
                    emptyState(message: "Runtime container not available.")
                }
            }
            .dsFeatureHeaderContentInsets(DSFeatureHeaderContentInsets.none)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func emptyState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
