import SwiftUI

struct ChatConversationView: View {
    let chat: Chat?
    let messages: [ChatMessage]
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onDeleteMessages: () -> Void
    let onDeleteChat: () -> Void
    let onPermissionChange: (ChatPermission?) -> Void

    @State private var isConfirmingDeleteMessages = false
    @State private var isConfirmingDeleteChat = false

    var body: some View {
        VStack(spacing: 0) {
            DSFeatureHeader(
                title: chat?.title ?? "Conversation",
                subtitle: chatSubtitle,
                systemImage: "text.bubble"
            ) {
                DSRefreshButton(isLoading: isLoading, action: onRefresh)

                Button(role: .destructive) {
                    isConfirmingDeleteMessages = true
                } label: {
                    Label("Delete Messages", systemImage: "trash")
                }
                .disabled(isLoading || chat == nil)
                .foregroundStyle(.red)
                .help("Delete only the selected chat messages and reset the chat state hash")

                Button(role: .destructive) {
                    isConfirmingDeleteChat = true
                } label: {
                    Label("Delete Chat", systemImage: "trash.slash")
                }
                .disabled(isLoading || chat == nil)
                .foregroundStyle(.red)
                .help("Delete the selected chat and all of its messages")
            }
            .confirmationDialog(
                "Delete chat messages?",
                isPresented: $isConfirmingDeleteMessages,
                titleVisibility: .visible
            ) {
                Button("Delete Chat Messages", role: .destructive, action: onDeleteMessages)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes only the selected chat messages from the local database and clears the chat state hash so crawling can rebuild it.")
            }
            .confirmationDialog(
                "Delete this chat?",
                isPresented: $isConfirmingDeleteChat,
                titleVisibility: .visible
            ) {
                Button("Delete Chat", role: .destructive, action: onDeleteChat)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes the selected chat and all of its messages from the local database.")
            }

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                if let chat {
                    HStack(spacing: 12) {
                        Text("Permission")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker(
                            "Permission",
                            selection: Binding(
                                get: { ChatPermissionChoice(permission: chat.permission) },
                                set: { onPermissionChange($0.permission) }
                            )
                        ) {
                            ForEach(ChatPermissionChoice.allCases) { choice in
                                Text(choice.title).tag(choice)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Divider()
                }

                Group {
                    if let errorMessage {
                        EmptyStateView(
                            title: "Unable to load messages",
                            message: errorMessage,
                            systemImage: "exclamationmark.triangle",
                            actionTitle: "Retry",
                            action: onRefresh
                        )
                    } else if chat == nil {
                        EmptyStateView(
                            title: "Select a chat",
                            message: "Choose a chat in the sidebar to view its conversation.",
                            systemImage: "sidebar.left"
                        )
                    } else if isLoading && messages.isEmpty {
                        ProgressView("Loading messages...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if messages.isEmpty {
                        EmptyStateView(
                            title: "No messages yet",
                            message: "This chat does not have persisted messages in the local cache.",
                            systemImage: "ellipsis.message"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                                    ChatMessageBubbleView(message: message)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var chatSubtitle: String {
        if let chat {
            return "Persisted history for \(chat.title)."
        }
        return "Persisted message history."
    }
}
