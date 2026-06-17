import SwiftUI

struct SettingsScreen: View {
    let settingsSectionRegistry: SettingsSectionRegistry?
    @State private var selectedFeatureTitle: String = ""

    private var featureTitles: [String] {
        guard let sections = settingsSectionRegistry?.sections else { return [] }
        var seen = Set<String>()
        var ordered: [String] = []
        for section in sections {
            let fTitle = section.featureTitle
            if !seen.contains(fTitle) {
                seen.insert(fTitle)
                ordered.append(fTitle)
            }
        }
        return ordered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DSFeatureHeader(title: "Settings")

            if let settingsSectionRegistry {
                let sections = settingsSectionRegistry.sections
                let titles = featureTitles

                if sections.isEmpty {
                    emptyState(message: "No settings sections registered for this profile.")
                } else {
                    Picker("Settings Feature Tab", selection: $selectedFeatureTitle) {
                        ForEach(titles, id: \.self) { title in
                            Text(title).tag(title)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            let activeSections = sections.filter { $0.featureTitle == selectedFeatureTitle }
                            ForEach(activeSections) { section in
                                DSTitledSection(title: section.title) {
                                    section.makeView()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                emptyState(message: "Runtime container not available.")
            }
        }
        .dsFeatureHeaderContentInsets(DSFeatureHeaderContentInsets.none)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if selectedFeatureTitle.isEmpty, let first = featureTitles.first {
                selectedFeatureTitle = first
            }
        }
        .onChange(of: featureTitles) { _, newTitles in
            if !newTitles.contains(selectedFeatureTitle), let first = newTitles.first {
                selectedFeatureTitle = first
            }
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
