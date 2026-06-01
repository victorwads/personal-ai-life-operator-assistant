import SwiftUI

struct ChatConversationView: View {
    let chat: Chat?
    let messages: [ChatMessage]
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onDelete: () -> Void
    let onPermissionChange: (ChatPermission?) -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            DSFeatureHeader(
                title: chat?.title ?? "Conversation",
                subtitle: chatSubtitle,
                systemImage: "text.bubble"
            ) {
                DSRefreshButton(isLoading: isLoading, action: onRefresh)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete Chat", systemImage: "trash")
                }
                .disabled(isLoading || chat == nil)
                .foregroundStyle(.red)
                .help("Delete the selected chat and messages")
            }
            .confirmationDialog(
                "Delete this chat?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Chat", role: .destructive, action: onDelete)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes the selected chat and all of its messages from the local database.")
            }

            Divider()

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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var chatSubtitle: String {
        if let chat {
            return "Persisted history for \(chat.title)."
        }
        return "Persisted message history."
    }
}
