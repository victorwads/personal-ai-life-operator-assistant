import SwiftUI

struct DesignSystemPreviewRootView: View {
    @State private var selection: DesignSystemPreviewRoute = .buttons

    var body: some View {
        NavigationSplitView {
            List(DesignSystemPreviewRoute.Category.allCases, selection: $selection) { category in
                Section(category.title) {
                    ForEach(DesignSystemPreviewRoute.routes(in: category)) { route in
                        Label(route.title, systemImage: route.systemImage)
                            .tag(route)
                    }
                }
            }
            .navigationTitle("Design System")
        } detail: {
            NavigationStack {
                selection.destination
                    .navigationTitle(selection.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}
