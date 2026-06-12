import Foundation

enum CommandCenterMenuRegistry {
    static func sections(
        showDeveloperItems: Bool = true,
        isWhatsAppWebViewVisible: Bool = true
    ) -> [CommandCenterSection] {
        allSections.compactMap { section in
            let visibleItems = section.items.filter { item in
                isVisible(
                    item,
                    showDeveloperItems: showDeveloperItems,
                    isWhatsAppWebViewVisible: isWhatsAppWebViewVisible
                )
            }

            guard !visibleItems.isEmpty else {
                return nil
            }

            return CommandCenterSection(id: section.id, title: section.title, items: visibleItems)
        }
    }

    private static let allSections: [CommandCenterSection] = [
        CommandCenterSection(
            id: "my-data",
            title: "My Data",
            items: [
                CommandCenterMenuItem(title: "My Profile", icon: "person.crop.circle", route: .myProfile),
                CommandCenterMenuItem(title: "Issues", icon: "exclamationmark.circle", route: .issues),
                CommandCenterMenuItem(title: "Chats", icon: "message", route: .chats),
                CommandCenterMenuItem(title: "Memories", icon: "brain.head.profile", route: .memories),
                CommandCenterMenuItem(title: "Sensitive Data", icon: "lock.shield", route: .sensitiveData),
                CommandCenterMenuItem(title: "Client Voice", icon: "waveform", route: .clientVoice),
                CommandCenterMenuItem(title: "Sent Messages", icon: "paperplane", route: .sentMessages)
            ]
        ),
        CommandCenterSection(
            id: "integrations",
            title: "Integrations",
            items: [
                CommandCenterMenuItem(title: "Google Workspace", icon: "square.grid.2x2", route: .googleWorkspace),
                CommandCenterMenuItem(
                    title: "WebView",
                    icon: "globe",
                    route: .whatsappWebView,
                    visibilityRule: .whatsappWebIntegrationOrDeveloperMode
                ),
                CommandCenterMenuItem(
                    title: "Web YAML Debug",
                    icon: "curlybraces.square",
                    route: .whatsappWebYAMLDebug,
                    developerModeOnly: true
                ),
//                CommandCenterMenuItem(
//                    title: "Native YAML Debug",
//                    icon: "curlybraces.square.fill",
//                    route: .whatsappNativeYAMLDebug,
//                    developerModeOnly: true
//                ),
                CommandCenterMenuItem(title: "Logs", icon: "doc.text", route: .whatsappLogs)
            ]
        ),
        CommandCenterSection(
            id: "server",
            title: "Server",
            items: [
                CommandCenterMenuItem(title: "Tools", icon: "wrench.and.screwdriver", route: .tools),
                CommandCenterMenuItem(title: "AI Connection", icon: "bolt.horizontal.circle", route: .aiConnection),
                CommandCenterMenuItem(title: "Resource Usage", icon: "chart.bar.doc.horizontal", route: .aiResourceUsage),
                CommandCenterMenuItem(title: "Server Logs", icon: "terminal", route: .serverLogs)
            ]
        ),
        CommandCenterSection(
            id: "settings",
            title: "Settings",
            items: [
                CommandCenterMenuItem(title: "Settings", icon: "gearshape", route: .settings)
            ]
        )
    ]

    private static func isVisible(
        _ item: CommandCenterMenuItem,
        showDeveloperItems: Bool,
        isWhatsAppWebViewVisible: Bool
    ) -> Bool {
        if item.developerModeOnly && !showDeveloperItems {
            return false
        }

        switch item.visibilityRule {
        case .always:
            return true
        case .whatsappWebIntegrationOrDeveloperMode:
            return isWhatsAppWebViewVisible
        }
    }
}
