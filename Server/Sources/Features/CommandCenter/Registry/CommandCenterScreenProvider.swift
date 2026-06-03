import SwiftUI

protocol CommandCenterScreenProvider {
    associatedtype Screen: View

    @ViewBuilder
    func screen(
        for route: CommandCenterRoute,
        profile: Profile,
        runtimeState: ProfileRuntimeState,
        windowState: ProfileWindowState
    ) -> Screen
}
