import SwiftUI

struct ChatListView: View {
    let chats: [Chat]
    let permissionMode: ChatPermissionMode
    @Binding var selectedChatId: String?
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onMarkAllAsRead: () -> Void
    let onSetChatPermission: (String, ChatPermission?) -> Void
    let onSelectChat: (String) -> Void
    let onDeleteAll: () -> Void

    @State private var isConfirmingDeleteAll = false
    @State private var searchQuery = ""

    private var filteredChats: [Chat] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return chats }

        return chats.compactMap { chat -> (chat: Chat, score: Double)? in
            let score = max(
                TextSimilarity.score(query: query, text: chat.title),
                TextSimilarity.score(query: query, text: chat.lastMessagePreview)
            )
            guard score > 0 else { return nil }
            return (chat: chat, score: score)
        }
        .sorted { $0.score > $1.score }
        .map { $0.chat }
    }

    var body: some View {
        VStack(spacing: 0) {
            DSFeatureHeader(
                title: "Chats",
                subtitle: "Persisted chat history for this profile.",
                systemImage: "message"
            ) {
                DSRefreshButton(isLoading: isLoading, action: onRefresh)

                Button(action: onMarkAllAsRead) {
                    Label("Mark All as Handled", systemImage: "checkmark.circle")
                }
                .disabled(isLoading || !hasUnhandledChats)
                .help("Mark all unhandled messages from every chat as handled")

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

            if !chats.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search chats by similarity...", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
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
            } else if filteredChats.isEmpty {
                EmptyStateView(
                    title: "Nenhum chat correspondente",
                    message: "Tente buscar por termos diferentes.",
                    systemImage: "magnifyingglass"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedChatId) {
                    if permissionMode == .denyAllExceptAllowed {
                        Section("Allowed") {
                            if allowedChats.isEmpty {
                                sectionPlaceholderRow(
                                    title: "Nenhuma conversa permitida ainda",
                                    message: "Permita um chat para ele aparecer nesta lista."
                                )
                            } else {
                                ForEach(allowedChats) { chat in
                                    chatRow(chat)
                                        .tag(chat.id)
                                }
                            }
                        }

                        Section("Not allowed") {
                            if notAllowedChats.isEmpty {
                                sectionPlaceholderRow(
                                    title: "Nenhuma conversa bloqueada ainda",
                                    message: "Chats negados aparecem aqui para revisão rápida."
                                )
                            } else {
                                ForEach(notAllowedChats) { chat in
                                    chatRow(chat)
                                        .tag(chat.id)
                                }
                            }
                        }
                    } else {
                        ForEach(filteredChats) { chat in
                            chatRow(chat)
                                .tag(chat.id)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var allowedChats: [Chat] {
        filteredChats.filter { ChatPermissionResolver.isChatAllowed($0, mode: permissionMode) }
    }

    private var notAllowedChats: [Chat] {
        filteredChats.filter { !ChatPermissionResolver.isChatAllowed($0, mode: permissionMode) }
    }

    private var hasUnhandledChats: Bool {
        chats.contains { $0.unhandledCount > 0 }
    }

    @ViewBuilder
    private func chatRow(_ chat: Chat) -> some View {
        ChatListRowView(chat: chat)
            .onTapGesture {
                if let chatID = chat.id {
                    onSelectChat(chatID)
                }
            }
            .contextMenu {
                ForEach(ChatPermissionChoice.allCases) { choice in
                    Button {
                        if let chatID = chat.id {
                            onSetChatPermission(chatID, choice.permission)
                        }
                    } label: {
                        HStack {
                            Text(choice.title)
                            if choice == ChatPermissionChoice(permission: chat.permission) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(chat.id == nil)
                }
            }
    }

    @ViewBuilder
    private func sectionPlaceholderRow(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .listRowBackground(Color.clear)
        .allowsHitTesting(false)
    }
}
