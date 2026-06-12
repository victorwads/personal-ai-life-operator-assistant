import SwiftUI

struct DesignSystemPreviewRootView: View {
    @State private var selection: DesignSystemPreviewRoute = .buttons
    @AppStorage("previewColorScheme") private var previewColorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme

    private var preferredColorScheme: ColorScheme? {
        switch previewColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var currentEffectiveColorScheme: ColorScheme {
        preferredColorScheme ?? systemColorScheme
    }

    private var toggleImageName: String {
        currentEffectiveColorScheme == .dark ? "sun.max.fill" : "moon.fill"
    }

    private var toggleLabelText: String {
        currentEffectiveColorScheme == .dark ? "Switch to Light Mode" : "Switch to Dark Mode"
    }

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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: toggleColorScheme) {
                    Label(toggleLabelText, systemImage: toggleImageName)
                }
                .help("Toggle between Light and Dark appearance")
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private func toggleColorScheme() {
        if currentEffectiveColorScheme == .dark {
            previewColorScheme = "light"
        } else {
            previewColorScheme = "dark"
        }
    }
}
