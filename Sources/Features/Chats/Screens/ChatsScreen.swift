import SwiftUI

struct ChatsScreen: View {
    var body: some View {
        FeatureScreenContainer(
            title: "Chats",
            subtitle: "WhatsApp chats and synced message history for this profile."
        ) {
            EmptyStateView(
                title: "Chat workspace is not implemented yet",
                message: "WhatsApp chats and synced message history will appear here once the chat workspace is implemented.",
                systemImage: "message"
            )
        }
    }
}
