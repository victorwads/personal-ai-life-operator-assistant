import SwiftUI

struct SettingsScreen: View {
    let settingsSectionRegistry: SettingsSectionRegistry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.largeTitle.weight(.semibold))

                if let settingsSectionRegistry {
                    let sections = settingsSectionRegistry.sections

                    if sections.isEmpty {
                        emptyState(message: "No settings sections registered for this profile.")
                    } else {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(.title2.weight(.semibold))

                                section.makeView()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.background)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(.quaternary, lineWidth: 1)
                                    )
                            }
                        }
                    }
                } else {
                    emptyState(message: "Runtime container not available.")
                }
            }
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
