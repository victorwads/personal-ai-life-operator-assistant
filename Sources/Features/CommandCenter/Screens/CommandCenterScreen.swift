import SwiftUI
import AppKit

struct CommandCenterScreen: View {
    let profile: Profile
    let runtimeState: ProfileRuntimeState
    let windowState: ProfileWindowState
    let statusRegistry: ProfileRuntimeStatusRegistry
    let appFeatures: AppFeatures

    @State private var selectedRoute: CommandCenterRoute? = .myProfile

    private let screenRegistry = CommandCenterScreenRegistry()

    var body: some View {
        NavigationSplitView {
            CommandCenterSidebar(
                sections: sections,
                whatsAppCrawlingFeature: whatsAppCrawlingFeature,
                onDetachWebView: detachWebViewFromSidebar,
                selectedRoute: selectedRouteBinding
            )
        } detail: {
            VStack(spacing: 0) {
                CommandCenterHeaderView(
                    profile: profile,
                    runtimeState: runtimeState,
                    windowState: windowState,
                    statusRegistry: statusRegistry
                )

                Divider()

                screenRegistry.screen(
                    for: selectedRoute ?? .myProfile,
                    profile: profile,
                    runtimeState: runtimeState,
                    windowState: windowState,
                    appFeatures: appFeatures
                )
            }
            .frame(minWidth: 620, minHeight: 520)
        }
        .frame(minWidth: 900, minHeight: 560)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help("Toggle Sidebar")
            }
        }
    }

    private var selectedRouteBinding: Binding<CommandCenterRoute> {
        Binding(
            get: { selectedRoute ?? .myProfile },
            set: { selectedRoute = $0 }
        )
    }

    private var sections: [CommandCenterSection] {
        CommandCenterMenuRegistry.sections(
            isWhatsAppWebViewVisible: whatsAppCrawlingFeature.webViewService.presentationMode == .embedded
        )
    }

    private var whatsAppCrawlingFeature: WhatsAppCrawlingFeature {
        appFeatures.feature(WhatsAppCrawlingFeature.self)
    }

    private func detachWebViewFromSidebar() {
        whatsAppCrawlingFeature.webViewService.detach()
        if selectedRoute == .whatsappWebView {
            selectedRoute = .myProfile
        }
    }

    private func toggleSidebar() {
        NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
    }
}
