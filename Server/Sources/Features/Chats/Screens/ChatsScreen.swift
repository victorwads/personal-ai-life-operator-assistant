import SwiftUI

struct ChatsScreen: View {
    let feature: ChatsFeature

    @State private var chats: [Chat] = []
    @State private var selectedChatId: String?
    @State private var messagesByChatId: [String: [ChatMessage]] = [:]
    @State private var isLoadingChats = false
    @State private var loadingMessagesChatId: String?
    @State private var errorMessage: String?

    var body: some View {
        HSplitView {
            ChatListView(
                chats: chats,
                selectedChatId: $selectedChatId,
                isLoading: isLoadingChats,
                errorMessage: errorMessage,
                onRefresh: loadChats
            )
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 420)

            ChatConversationView(
                chat: selectedChat,
                messages: selectedMessages,
                isLoading: isLoadingMessages,
                errorMessage: errorMessage,
                onRefresh: refreshSelection
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

    private func loadChats() async {
        isLoadingChats = true
        errorMessage = nil
        defer { isLoadingChats = false }

        do {
            let loaded = try await feature.repository.listChats()
            chats = loaded

            if let current = selectedChatId, loaded.contains(where: { $0.id == current }) {
                return
            }
            selectedChatId = loaded.first?.id
        } catch {
            errorMessage = "Failed to load chats: \(error.localizedDescription)"
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
}
