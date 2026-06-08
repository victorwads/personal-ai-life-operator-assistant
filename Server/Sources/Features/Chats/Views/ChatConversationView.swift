import SwiftUI

struct ChatConversationView: View {
    let chat: Chat?
    let messages: [ChatMessage]
    let isLoading: Bool
    let errorMessage: String?
    let onDeleteMessages: () -> Void
    let onDeleteChat: () -> Void
    let onPermissionChange: (ChatPermission?) -> Void
    let onToggleMessageHandled: (ChatMessage) -> Void
    let onMarkMessageAndOlderHandled: (ChatMessage) -> Void
    let onMarkMessageAndNewerUnhandled: (ChatMessage) -> Void
    let onDeleteMessage: (ChatMessage) -> Void
    let onMarkSelectedMessagesHandled: ([String], Bool) -> Void
    let onMarkAllHandled: () -> Void
    let onToggleMessageSentByAssistant: (ChatMessage) -> Void

    @State private var isConfirmingDeleteMessages = false
    @State private var isConfirmingDeleteChat = false
    @State private var messagePendingDeletion: ChatMessage?
    @State private var isConfirmingDeleteMessage = false
    @State private var isSelectionModeEnabled = false
    @State private var selectedMessageIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            DSFeatureHeader(
                title: chat?.title ?? "Conversation",
                subtitle: chatSubtitle,
                systemImage: "text.bubble"
            ) {
                Button {
                    onMarkAllHandled()
                    exitSelectionMode()
                } label: {
                    Label("Mark all handled", systemImage: "checkmark.circle")
                }
                .disabled(isLoading || chat == nil)

                if isSelectionModeEnabled {
                    Button("Cancel Selection") {
                        exitSelectionMode()
                    }
                    .disabled(isLoading)

                    Button("Mark Selected Handled") {
                        beginMarkSelectedMessagesHandled(handled: true)
                    }
                    .disabled(isLoading || selectedMessageIds.isEmpty)

                    Button("Mark Selected Unhandled") {
                        beginMarkSelectedMessagesHandled(handled: false)
                    }
                    .disabled(isLoading || selectedMessageIds.isEmpty)
                } else {
                    Button("Select") {
                        isSelectionModeEnabled = true
                    }
                    .disabled(isLoading || chat == nil || messages.isEmpty)
                }

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
            .confirmationDialog(
                "Delete this message?",
                isPresented: $isConfirmingDeleteMessage,
                titleVisibility: .visible
            ) {
                Button("Delete Message", role: .destructive) {
                    if let messagePendingDeletion {
                        onDeleteMessage(messagePendingDeletion)
                    }
                    isConfirmingDeleteMessage = false
                    messagePendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    isConfirmingDeleteMessage = false
                    messagePendingDeletion = nil
                }
            } message: {
                Text(deleteMessageConfirmationText)
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
                            systemImage: "exclamationmark.triangle"
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
                                    ChatMessageBubbleView(
                                        message: message,
                                        isSelected: selectedMessageIds.contains(message.id ?? ""),
                                        isSelectionModeEnabled: isSelectionModeEnabled,
                                        onToggleHandled: onToggleMessageHandled,
                                        onMarkThisAndOlderHandled: onMarkMessageAndOlderHandled,
                                        onMarkThisAndNewerUnhandled: onMarkMessageAndNewerUnhandled,
                                        onDeleteMessage: beginDeleteMessage,
                                        onSelectionChange: updateSelection(for:isSelected:),
                                        onToggleSentByAssistant: onToggleMessageSentByAssistant
                                    )
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: chat?.id) { _, _ in
            exitSelectionMode()
        }
        .onChange(of: messages) { _, _ in
            pruneSelectionToVisibleMessages()
        }
    }

    private var chatSubtitle: String {
        if let chat {
            return "Persisted history for \(chat.title)."
        }
        return "Persisted message history."
    }

    private func updateSelection(for message: ChatMessage, isSelected: Bool) {
        guard let messageId = message.id, !messageId.isEmpty else {
            return
        }

        if isSelected {
            selectedMessageIds.insert(messageId)
        } else {
            selectedMessageIds.remove(messageId)
        }
    }

    private func beginMarkSelectedMessagesHandled(handled: Bool) {
        let ids = Array(selectedMessageIds)
        guard !ids.isEmpty else { return }
        onMarkSelectedMessagesHandled(ids, handled)
        exitSelectionMode()
    }

    private func beginDeleteMessage(_ message: ChatMessage) {
        messagePendingDeletion = message
        isConfirmingDeleteMessage = true
    }

    private func exitSelectionMode() {
        isSelectionModeEnabled = false
        selectedMessageIds = []
    }

    private func pruneSelectionToVisibleMessages() {
        let visibleMessageIds = Set(messages.compactMap(\.id))
        selectedMessageIds = selectedMessageIds.intersection(visibleMessageIds)
    }

    private var deleteMessageConfirmationText: String {
        guard let message = messagePendingDeletion else {
            return "This deletes the selected chat message from the local database."
        }

        let author = message.author?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary: String

        if let author, !author.isEmpty, let text, !text.isEmpty {
            summary = "\(author): \(text)"
        } else if let text, !text.isEmpty {
            summary = text
        } else {
            summary = "this message"
        }

        return "This deletes \(summary) from the local database."
    }
}
