import SwiftUI

struct ChatsScreen: View {
    let feature: ChatsFeature

    @State private var chats: [Chat] = []
    @State private var selectedChatId: String?
    @State private var messagesByChatId: [String: [ChatMessage]] = [:]
    @State private var isLoadingChats = false
    @State private var loadingMessagesChatId: String?
    @State private var isDeletingAllChats = false
    @State private var deletingChatId: String?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            ChatListView(
                chats: chats,
                permissionMode: feature.crawlingSettings.chatPermissionMode,
                selectedChatId: $selectedChatId,
                isLoading: isLoadingChats || isDeletingAllChats,
                errorMessage: errorMessage,
                onRefresh: loadChats,
                onDeleteAll: beginDeleteAllChatsAndMessages
            )
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 420)

            ChatConversationView(
                chat: selectedChat,
                messages: selectedMessages,
                isLoading: isLoadingMessages || isDeletingSelectedChat,
                errorMessage: errorMessage,
                onRefresh: refreshSelection,
                onDelete: beginDeleteSelectedChatAndMessages,
                onPermissionChange: beginSetSelectedChatPermission
            )
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            guard chats.isEmpty else { return }
            await loadChats()
        }
        .task(id: selectedChatId) {
            guard let selectedChatId, messagesByChatId[selectedChatId] == nil else { return }
            await loadMessages(chatId: selectedChatId)
        }
    }

    private var selectedChat: Chat? {
        guard let selectedChatId else { return nil }
        return chats.first(where: { $0.id == selectedChatId })
    }

    private var selectedMessages: [ChatMessage] {
        guard let selectedChatId else { return [] }
        return messagesByChatId[selectedChatId] ?? []
    }

    private var isLoadingMessages: Bool {
        guard let selectedChatId else { return false }
        return loadingMessagesChatId == selectedChatId
    }

    private var isDeletingSelectedChat: Bool {
        guard let selectedChatId else { return false }
        return deletingChatId == selectedChatId
    }

    private func refreshSelection() {
        if let selectedChatId {
            Task { await loadMessages(chatId: selectedChatId, force: true) }
        } else {
            Task { await loadChats() }
        }
    }

    private func loadChats() {
        Task { await loadChats() }
    }

    private func beginDeleteAllChatsAndMessages() {
        Task { await deleteAllChatsAndMessages() }
    }

    private func beginDeleteSelectedChatAndMessages() {
        Task { await deleteSelectedChatAndMessages() }
    }

    private func beginSetSelectedChatPermission(_ permission: ChatPermission?) {
        Task { await setSelectedChatPermission(permission) }
    }

    private func loadChats(autoSelect: Bool = true) async {
        isLoadingChats = true
        errorMessage = nil
        defer { isLoadingChats = false }

        do {
            let previousSelectedChat = selectedChat
            let loaded = try await feature.repository.listChats()
            chats = loaded

            if let current = selectedChatId, loaded.contains(where: { $0.id == current }) {
                if let updatedSelectedChat = loaded.first(where: { $0.id == current }),
                   shouldReloadMessages(
                    previous: previousSelectedChat,
                    current: updatedSelectedChat
                   ) {
                    await loadMessages(chatId: current, force: true)
                }
                return
            }
            selectedChatId = autoSelect ? loaded.first?.id : nil
        } catch {
            errorMessage = "Failed to load chats: \(error.localizedDescription)"
        }
    }

    private func deleteAllChatsAndMessages() async {
        isDeletingAllChats = true
        errorMessage = nil
        defer { isDeletingAllChats = false }

        do {
            try await feature.repository.deleteAllChatsAndMessages()
            selectedChatId = nil
            messagesByChatId = [:]
            chats = []
            await loadChats(autoSelect: false)
        } catch {
            let message = "Failed to delete all chats and messages: \(error.localizedDescription)"
            print(message)
            errorMessage = message
        }
    }

    private func deleteSelectedChatAndMessages() async {
        guard let chatId = selectedChatId else {
            return
        }

        deletingChatId = chatId
        errorMessage = nil
        defer {
            if deletingChatId == chatId {
                deletingChatId = nil
            }
        }

        do {
            try await feature.repository.deleteChatAndMessages(chatId: chatId)
            selectedChatId = nil
            messagesByChatId[chatId] = nil
            await loadChats(autoSelect: false)
        } catch {
            let message = "Failed to delete chat \(chatId) and messages: \(error.localizedDescription)"
            print(message)
            errorMessage = message
        }
    }

    private func loadMessages(chatId: String, force: Bool = false) async {
        if !force, messagesByChatId[chatId] != nil {
            return
        }

        loadingMessagesChatId = chatId
        errorMessage = nil
        defer {
            if loadingMessagesChatId == chatId {
                loadingMessagesChatId = nil
            }
        }

        do {
            let messages = try await feature.repository.listMessages(chatId: chatId, limit: 200)
            messagesByChatId[chatId] = messages
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
        }
    }

    private func setSelectedChatPermission(_ permission: ChatPermission?) async {
        guard let chatId = selectedChatId else { return }
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else { return }

        let currentChat = chats[chatIndex]
        guard currentChat.permission != permission else { return }

        var updatedChat = currentChat
        updatedChat.permission = permission

        do {
            try await feature.repository.upsertChat(updatedChat)
            chats[chatIndex] = updatedChat
        } catch {
            errorMessage = "Failed to update chat permission: \(error.localizedDescription)"
        }
    }

    private func shouldReloadMessages(previous: Chat?, current: Chat) -> Bool {
        guard let previous else {
            return true
        }

        return previous.stateHash != current.stateHash
            || previous.unreadCount != current.unreadCount
            || previous.lastMessagePreview != current.lastMessagePreview
            || previous.lastMessageTimeText != current.lastMessageTimeText
    }
}
