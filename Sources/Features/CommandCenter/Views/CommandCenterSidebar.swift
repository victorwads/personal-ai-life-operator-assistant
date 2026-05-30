import SwiftUI

struct CommandCenterSidebar: View {
    let sections: [CommandCenterSection]
    let whatsAppCrawlingFeature: WhatsAppCrawlingFeature
    let onDetachWebView: () -> Void
    @Binding var selectedRoute: CommandCenterRoute

    var body: some View {
        List(selection: $selectedRoute) {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        row(for: item)
                            .tag(item.route)
                    }
                }
            }
        }
        .navigationTitle("Command Center")
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private func row(for item: CommandCenterMenuItem) -> some View {
        HStack(spacing: 8) {
            Label(item.title, systemImage: item.icon)
            Spacer(minLength: 8)

            if shouldShowDetachButton(for: item) {
                Button {
                    onDetachWebView()
                } label: {
                    Image(systemName: "rectangle.on.rectangle")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Open WebView in separate window")
            }
        }
        .contentShape(Rectangle())
    }

    private func shouldShowDetachButton(for item: CommandCenterMenuItem) -> Bool {
        guard item.route == .whatsappWebView else { return false }
        let whatsAppWebViewService = whatsAppCrawlingFeature.webViewService
        guard whatsAppWebViewService.state == .started else { return false }
        return whatsAppWebViewService.presentationMode == .embedded
    }
}
