import SwiftUI

struct SettingsSectionDefinition: Identifiable {
    let scopeName: String
    let title: String
    let makeView: () -> AnyView

    init(
        scopeName: String,
        title: String,
        makeView: @escaping () -> AnyView
    ) {
        self.scopeName = scopeName
        self.title = title
        self.makeView = makeView
    }

    var id: String { scopeName }
}
