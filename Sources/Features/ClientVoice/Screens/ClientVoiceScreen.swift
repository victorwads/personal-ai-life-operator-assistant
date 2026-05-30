import SwiftUI

struct ClientVoiceScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Client Voice",
            subtitle: "Client-facing asks, confirmations, and assistant-to-client messages."
        ) {
            EmptyStateView(
                title: "Client voice workspace is not implemented yet",
                message: "Client-facing asks, confirmations, and assistant-to-client messages will appear here.",
                systemImage: "waveform"
            )
        }
    }
}
