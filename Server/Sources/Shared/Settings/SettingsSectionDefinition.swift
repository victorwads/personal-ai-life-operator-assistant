import SwiftUI

struct SettingsSectionDefinition: Identifiable {
    let scopeName: String
    let title: String
    let featureTitle: String
    let makeView: () -> AnyView

    init(
        scopeName: String,
        title: String,
        featureTitle: String? = nil,
        makeView: @escaping () -> AnyView
    ) {
        self.scopeName = scopeName
        self.title = title
        self.featureTitle = featureTitle ?? title
        self.makeView = makeView
    }

    var id: String { scopeName }
}
