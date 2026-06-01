import SwiftUI

struct ChatListView: View {
    let chats: [Chat]
    @Binding var selectedChatId: String?
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onDeleteAll: () -> Void

    @State private var isConfirmingDeleteAll = false

    var body: some View {
        VStack(spacing: 0) {
            DSFeatureHeader(
                title: "Chats",
                subtitle: "Persisted chat history for this profile.",
                systemImage: "message"
            ) {
                DSRefreshButton(isLoading: isLoading, action: onRefresh)

                Button(role: .destructive) {
                    isConfirmingDeleteAll = true
                } label: {
                    Label("Delete All", systemImage: "trash")
                }
                .disabled(isLoading || chats.isEmpty)
                .foregroundStyle(.red)
                .help("Delete all chats and messages")
            }
            .confirmationDialog(
                "Delete all chats?",
                isPresented: $isConfirmingDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete All Chats", role: .destructive, action: onDeleteAll)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all chats and all chat messages from the local database.")
            }

            Divider()

            if let errorMessage {
                EmptyStateView(
                    title: "Unable to load chats",
                    message: errorMessage,
                    systemImage: "exclamationmark.triangle",
                    actionTitle: "Retry",
                    action: onRefresh
                )
            } else if isLoading && chats.isEmpty {
                ProgressView("Loading chats...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chats.isEmpty {
                EmptyStateView(
                    title: "No chats found",
                    message: "Chats will appear here after crawling syncs message history.",
                    systemImage: "tray"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(chats, selection: $selectedChatId) { chat in
                    ChatListRowView(chat: chat)
                        .tag(chat.id)
                }
                .listStyle(.sidebar)
            }
        }
    }
}
