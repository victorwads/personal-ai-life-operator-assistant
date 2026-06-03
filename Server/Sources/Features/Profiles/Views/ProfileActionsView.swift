import SwiftUI

struct ProfileActionsView: View {
    let runtimeState: ProfileRuntimeState
    let windowState: ProfileWindowState
    let onStart: () -> Void
    let onStop: () -> Void
    let onShowWindow: () -> Void
    let onHideWindow: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if runtimeState == .running || runtimeState == .starting {
                Button("Stop") { onStop() }
                    .buttonStyle(.bordered)
            } else {
                Button("Start") { onStart() }
                    .buttonStyle(.borderedProminent)
            }

            if windowState == .visible {
                Button("Hide Window") { onHideWindow() }
                    .buttonStyle(.bordered)
            } else {
                Button("Open Window") { onShowWindow() }
                    .buttonStyle(.bordered)
            }
        }
    }
}
