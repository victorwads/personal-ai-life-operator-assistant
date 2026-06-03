import Foundation

struct CommandCenterMenuItem: Identifiable, Hashable {
    enum VisibilityRule: Hashable {
        case always
        case whatsappWebIntegrationOrDeveloperMode
    }

    let id: String
    let title: String
    let icon: String
    let route: CommandCenterRoute
    let developerModeOnly: Bool
    let visibilityRule: VisibilityRule

    init(
        id: String? = nil,
        title: String,
        icon: String,
        route: CommandCenterRoute,
        developerModeOnly: Bool = false,
        visibilityRule: VisibilityRule = .always
    ) {
        self.id = id ?? route.id
        self.title = title
        self.icon = icon
        self.route = route
        self.developerModeOnly = developerModeOnly
        self.visibilityRule = visibilityRule
    }
}
