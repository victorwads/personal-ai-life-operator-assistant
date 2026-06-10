import SwiftUI

struct ChatsScreen: View {
    let feature: ChatsFeature

    @State private var chats: [Chat] = []
    @State private var selectedChatId: String?
    @State private var messagesByChatId: [String: [ChatMessage]] = [:]
    @State private var messagesListener: FirestoreListenerToken?
    @State private var isLoadingChats = false
    @State private var loadingMessagesChatId: String?
    @State private var isDeletingAllChats = false
    @State private var deletingChatId: String?
    @State private var deletingMessageId: String?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            ChatListView(
                chats: chats,
                permissionMode: feature.crawlingSettings.chatPermissionMode,
                selectedChatId: $selectedChatId,
                isLoading: isLoadingChats || isDeletingAllChats,
                errorMessage: errorMessage,
                onRefresh: requestLoadChats,
                onMarkAllAsRead: beginMarkAllChatsMessagesHandled,
                onSetChatPermission: beginSetChatPermission,
                onSelectChat: beginSelectChat,
                onDeleteAll: beginDeleteAllChatsAndMessages
            )
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 420)

            ChatConversationView(
                chat: selectedChat,
                messages: selectedMessages,
                isLoading: isLoadingMessages || isDeletingSelectedChat || isDeletingSelectedMessage,
                errorMessage: errorMessage,
                onDeleteMessages: beginDeleteSelectedChatMessages,
                onDeleteChat: beginDeleteSelectedChatAndMessages,
                onPermissionChange: beginSetSelectedChatPermission,
                onToggleMessageHandled: beginToggleMessageHandled,
                onMarkMessageAndOlderHandled: beginMarkMessageAndOlderHandled,
                onMarkMessageAndNewerUnhandled: beginMarkMessageAndNewerUnhandled,
                onDeleteMessage: beginDeleteSelectedMessage,
                onMarkSelectedMessagesHandled: beginMarkSelectedMessagesHandled,
                onMarkAllHandled: beginMarkAllSelectedChatMessagesHandled,
                onToggleMessageSentByAssistant: beginToggleMessageSentByAssistant
            )
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            guard chats.isEmpty else { return }
            await loadChats()
        }
        .task(id: selectedChatId) {
            await refreshSelectedChatMessagesListener()
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

    private var isDeletingSelectedMessage: Bool {
        deletingMessageId != nil
    }

    private func requestLoadChats() {
        Task { await loadChats() }
    }

    private func beginDeleteAllChatsAndMessages() {
        Task { await deleteAllChatsAndMessages() }
    }

    private func beginMarkAllChatsMessagesHandled() {
        Task { await markAllChatsMessagesHandled() }
    }

    private func beginDeleteSelectedChatAndMessages() {
        Task { await deleteSelectedChatAndMessages() }
    }

    private func beginDeleteSelectedChatMessages() {
        Task { await deleteSelectedChatMessages() }
    }

    private func beginDeleteSelectedMessage(_ message: ChatMessage) {
        Task { await deleteSelectedMessage(message) }
    }

    private func beginSetSelectedChatPermission(_ permission: ChatPermission?) {
        Task { await setSelectedChatPermission(permission) }
    }

    private func beginSetChatPermission(chatId: String, permission: ChatPermission?) {
        Task { await setChatPermission(chatId: chatId, permission: permission, selectChat: true) }
    }

    private func beginSelectChat(_ chatId: String) {
        selectedChatId = chatId
    }

    @MainActor
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

    @MainActor
    private func deleteAllChatsAndMessages() async {
        isDeletingAllChats = true
        errorMessage = nil
        defer { isDeletingAllChats = false }

        do {
            try await feature.repository.deleteAllChatsAndMessages()
            selectedChatId = nil
            messagesByChatId = [:]
            messagesListener?.cancel()
            messagesListener = nil
            chats = []
            await loadChats(autoSelect: false)
        } catch {
            let message = "Failed to delete all chats and messages: \(error.localizedDescription)"
            print(message)
            errorMessage = message
        }
    }

    @MainActor
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
            messagesListener?.cancel()
            messagesListener = nil
            await loadChats(autoSelect: false)
        } catch {
            let message = "Failed to delete chat \(chatId) and messages: \(error.localizedDescription)"
            print(message)
            errorMessage = message
        }
    }

    @MainActor
    private func deleteSelectedChatMessages() async {
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
            try await feature.repository.deleteChatMessages(chatId: chatId)
            messagesByChatId[chatId] = []

            if let chatIndex = chats.firstIndex(where: { $0.id == chatId }) {
                chats[chatIndex].stateHash = ""
                chats[chatIndex].unhandledCount = 0
                chats[chatIndex].unreadCount = 0
                chats[chatIndex].lastMessagePreview = nil
                chats[chatIndex].lastMessageLocalMediaPath = nil
                chats[chatIndex].lastMessageTimeText = nil
            }

            await loadChats(autoSelect: false)
            await loadMessages(chatId: chatId, force: true)
        } catch {
            let message = "Failed to delete messages for chat \(chatId): \(error.localizedDescription)"
            print(message)
            errorMessage = message
        }
    }

    @MainActor
    private func deleteSelectedMessage(_ message: ChatMessage) async {
        guard let chatId = selectedChatId, let messageId = message.id, !messageId.isEmpty else { return }

        deletingMessageId = messageId
        errorMessage = nil
        defer {
            if deletingMessageId == messageId {
                deletingMessageId = nil
            }
        }

        do {
            try await feature.repository.deleteMessage(id: messageId)
            await loadMessages(chatId: chatId, force: true)
            await loadChats(autoSelect: false)
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
        }
    }

    @MainActor
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

    @MainActor
    private func setSelectedChatPermission(_ permission: ChatPermission?) async {
        guard let chatId = selectedChatId else { return }
        await setChatPermission(chatId: chatId, permission: permission, selectChat: false)
    }

    @MainActor
    private func setChatPermission(chatId: String, permission: ChatPermission?, selectChat: Bool) async {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else { return }

        let currentChat = chats[chatIndex]
        guard currentChat.permission != permission else { return }

        if selectChat {
            selectedChatId = chatId
        }

        var updatedChat = currentChat
        updatedChat.permission = permission
        updatedChat.stateHash = ""

        do {
            try await feature.repository.updateChatPermission(chatId: chatId, permission: permission)
            chats[chatIndex] = updatedChat
            await loadChats(autoSelect: false)
        } catch {
            errorMessage = "Failed to update chat permission: \(error.localizedDescription)"
        }
    }

    private func beginToggleMessageHandled(_ message: ChatMessage) {
        Task { await toggleMessageHandled(message) }
    }

    private func beginToggleMessageSentByAssistant(_ message: ChatMessage) {
        Task { await toggleMessageSentByAssistant(message) }
    }

    private func beginMarkMessageAndOlderHandled(_ message: ChatMessage) {
        Task { await markMessageAndOlderHandled(message) }
    }

    private func beginMarkMessageAndNewerUnhandled(_ message: ChatMessage) {
        Task { await markMessageAndNewerUnhandled(message) }
    }

    private func beginMarkSelectedMessagesHandled(ids: [String], handled: Bool) {
        Task { await setSelectedMessagesHandled(ids: ids, handled: handled) }
    }

    private func beginMarkAllSelectedChatMessagesHandled() {
        Task { await markAllSelectedChatMessagesHandled() }
    }

    @MainActor
    private func refreshSelectedChatMessagesListener() async {
        messagesListener?.cancel()
        messagesListener = nil

        guard let chatId = selectedChatId else {
            return
        }

        messagesListener = feature.repository.observeMessages(chatId: chatId) {
            Task { @MainActor in
                await self.loadMessages(chatId: chatId, force: true)
            }
        }

        await loadMessages(chatId: chatId, force: true)
    }

    @MainActor
    private func toggleMessageHandled(_ message: ChatMessage) async {
        guard let chatId = selectedChatId, let messageId = message.id, !messageId.isEmpty else { return }

        do {
            try await feature.repository.setMessageHandled(
                chatId: chatId,
                messageId: messageId,
                handled: !message.handled
            )
            await loadMessages(chatId: chatId, force: true)
            await loadChats(autoSelect: false)
        } catch {
            errorMessage = "Failed to update message handled state: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func toggleMessageSentByAssistant(_ message: ChatMessage) async {
        guard let chatId = selectedChatId, let messageId = message.id, !messageId.isEmpty else { return }

        do {
            try await feature.repository.setMessageSentByAssistant(
                chatId: chatId,
                messageId: messageId,
                sentByAssistant: !(message.sentByAssistant ?? false)
            )
            await loadMessages(chatId: chatId, force: true)
        } catch {
            errorMessage = "Failed to update message assistant state: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func markMessageAndOlderHandled(_ message: ChatMessage) async {
        guard let chatId = selectedChatId, let messageId = message.id, !messageId.isEmpty else { return }

        do {
            _ = try await feature.repository.markMessagesHandledThrough(
                chatId: chatId,
                lastChatMessageId: messageId
            )
            await loadMessages(chatId: chatId, force: true)
            await loadChats(autoSelect: false)
        } catch {
            errorMessage = "Failed to mark this message and older messages as handled: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func markMessageAndNewerUnhandled(_ message: ChatMessage) async {
        guard let chatId = selectedChatId, let messageId = message.id, !messageId.isEmpty else { return }

        do {
            _ = try await feature.repository.markMessagesUnhandledFrom(
                chatId: chatId,
                firstChatMessageId: messageId
            )
            await loadMessages(chatId: chatId, force: true)
            await loadChats(autoSelect: false)
        } catch {
            errorMessage = "Failed to mark this message and newer messages as unhandled: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func setSelectedMessagesHandled(ids: [String], handled: Bool) async {
        guard let chatId = selectedChatId else { return }

        do {
            _ = try await feature.repository.setMessagesHandled(
                chatId: chatId,
                messageIds: ids,
                handled: handled
            )
            await loadMessages(chatId: chatId, force: true)
            await loadChats(autoSelect: false)
        } catch {
            errorMessage = "Failed to update selected messages: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func markAllSelectedChatMessagesHandled() async {
        guard let chatId = selectedChatId else { return }

        do {
            _ = try await feature.repository.markAllMessagesHandled(chatId: chatId)
            await loadMessages(chatId: chatId, force: true)
            await loadChats(autoSelect: false)
        } catch {
            errorMessage = "Failed to mark all chat messages as handled: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func markAllChatsMessagesHandled() async {
        do {
            _ = try await feature.repository.markAllUnhandledMessagesHandled()
            if let selectedChatId {
                await loadMessages(chatId: selectedChatId, force: true)
            }
            await loadChats(autoSelect: false)
        } catch {
            errorMessage = "Failed to mark all chat messages as handled: \(error.localizedDescription)"
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
