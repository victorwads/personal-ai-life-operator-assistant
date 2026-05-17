import Foundation

enum WhatsAppMemoryStoreEvent {
    case conversationsUpdated([ConversationSummary])
    case chatStateUpdated(ChatState)
    case selectedConversationChanged(String?)
}

struct WaitForMessageResult {
    let chat: ConversationSummary
    let message: Message
}

@MainActor
final class WhatsAppMemoryStore: ObservableObject {
    @Published private(set) var conversations: [ConversationSummary] = []
    @Published private(set) var selectedConversationId: String?
    @Published private(set) var selectedChatState: ChatState?

    private var chatStatesById: [String: ChatState] = [:]
    private var listeners: [UUID: (WhatsAppMemoryStoreEvent) -> Void] = [:]
    private let sendPrefixRepository: MCPSendPrefixRepository

    init(sendPrefixRepository: MCPSendPrefixRepository = .shared) {
        self.sendPrefixRepository = sendPrefixRepository
    }

    func replaceAllChatStates(_ chatStatesById: [String: ChatState]) {
        let persistedAt = Date()
        var normalizedStatesById: [String: ChatState] = [:]
        var normalizedConversationsById: [String: ConversationSummary] = [:]

        for state in chatStatesById.values {
            let canonicalChatId = canonicalChatId(for: state.chat.name)
            let normalizedChat = state.chat.replacing(id: canonicalChatId)
            let normalizedState = normalizeChatState(
                state.replacing(
                    chat: normalizedChat,
                    messages: state.messages.map { $0.replacing(chatId: canonicalChatId) }
                ),
                persistedAt: persistedAt
            )
            normalizedStatesById[canonicalChatId] = normalizedState
            normalizedConversationsById[canonicalChatId] = normalizedChat
        }

        self.chatStatesById = normalizedStatesById
        self.conversations = Array(normalizedConversationsById.values).sorted { left, right in
            if left.isPinned != right.isPinned {
                return left.isPinned && !right.isPinned
            }
            if left.unreadCount != right.unreadCount {
                return left.unreadCount > right.unreadCount
            }
            if left.lastMessageAtText != right.lastMessageAtText {
                return (left.lastMessageAtText ?? "").localizedStandardCompare(right.lastMessageAtText ?? "") == .orderedDescending
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }

        if let selectedConversationId, let cached = self.chatStatesById[canonicalChatId(for: selectedConversationId)] {
            selectedChatState = cached
        } else if let selectedConversationId, let conversation = self.conversations.first(where: { $0.id == canonicalChatId(for: selectedConversationId) }) {
            selectedChatState = ChatState(
                chat: conversation,
                messages: [],
                composeFocused: false,
                canSendText: false
            )
        } else {
            selectedChatState = nil
        }
    }

    func snapshotChatStatesById() -> [String: ChatState] {
        chatStatesById
    }

    func replaceConversations(_ conversations: [ConversationSummary]) {
        for conversation in conversations {
            let canonicalId = canonicalChatId(for: conversation.name)
            let normalizedConversation = conversation.replacing(id: canonicalId)

            if let index = self.conversations.firstIndex(where: { $0.id == canonicalId }) {
                self.conversations[index] = normalizedConversation
            } else {
                self.conversations.append(normalizedConversation)
            }

            if let cachedState = chatStatesById[canonicalId] {
                chatStatesById[canonicalId] = cachedState.replacing(chat: normalizedConversation)
                if selectedConversationId == canonicalId {
                    selectedChatState = chatStatesById[canonicalId]
                }
            }
        }

        self.conversations = Array(
            Dictionary(grouping: self.conversations, by: \.id)
                .compactMapValues { $0.last }
                .values
        )
        .sorted { left, right in
            if left.isPinned != right.isPinned {
                return left.isPinned && !right.isPinned
            }
            if left.unreadCount != right.unreadCount {
                return left.unreadCount > right.unreadCount
            }
            if left.lastMessageAtText != right.lastMessageAtText {
                return (left.lastMessageAtText ?? "").localizedStandardCompare(right.lastMessageAtText ?? "") == .orderedDescending
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }

        if let selectedConversationId {
            let canonicalSelectedId = canonicalChatId(for: selectedConversationId)
            if let latestSelectedConversation = self.conversations.first(where: { $0.id == canonicalSelectedId }) {
                selectedChatState = chatStatesById[canonicalSelectedId]?.replacing(chat: latestSelectedConversation)
                    ?? ChatState(
                        chat: latestSelectedConversation,
                        messages: [],
                        composeFocused: false,
                        canSendText: false
                    )
            }
        }

        emit(.conversationsUpdated(self.conversations))
    }

    func upsertChatState(_ chatState: ChatState) {
        let persistedAt = Date()
        let canonicalId = canonicalChatId(for: chatState.chat.name)
        let normalizedState = normalizeChatState(
            chatState.replacing(
                chat: chatState.chat.replacing(id: canonicalId),
                messages: chatState.messages.map { $0.replacing(chatId: canonicalId) }
            ),
            persistedAt: persistedAt
        )
        let existingState = chatStatesById[canonicalId]
        let mergedMessages = mergeMessages(existing: existingState?.messages ?? [], incoming: normalizedState.messages, persistedAt: persistedAt)
        let mergedState = normalizedState.replacing(
            messages: mergedMessages,
            composeFocused: normalizedState.composeFocused,
            canSendText: normalizedState.canSendText
        )
        chatStatesById[canonicalId] = mergedState

        if selectedConversationId == canonicalId {
            selectedChatState = mergedState
        }

        emit(.chatStateUpdated(mergedState))
    }

    func selectConversation(id: String) {
        let canonicalId = canonicalChatId(for: id)
        selectedConversationId = canonicalId
        if let conversation = conversations.first(where: { $0.id == canonicalId }) {
            selectedChatState = chatStatesById[canonicalId] ?? ChatState(
                chat: conversation,
                messages: [],
                composeFocused: false,
                canSendText: false
            )
        } else {
            selectedChatState = chatStatesById[canonicalId]
        }
        emit(.selectedConversationChanged(canonicalId))
    }

    func clearSelection() {
        selectedConversationId = nil
        selectedChatState = nil
        emit(.selectedConversationChanged(nil))
    }

    func removeConversation(id: String) {
        let canonicalId = canonicalChatId(for: id)
        conversations.removeAll { $0.id == canonicalId }
        chatStatesById.removeValue(forKey: canonicalId)

        if selectedConversationId == canonicalId {
            clearSelection()
        } else {
            emit(.conversationsUpdated(conversations))
        }
    }

    /// Clears all cached chat histories (messages + per-chat state) while preserving the current conversation list.
    /// Does not touch allow/deny lists (stored elsewhere) or the parsed conversation summaries.
    func clearAllCachedChatHistories() {
        chatStatesById.removeAll(keepingCapacity: false)

        if let selectedConversationId, let conversation = conversations.first(where: { $0.id == selectedConversationId }) {
            selectedChatState = ChatState(
                chat: conversation,
                messages: [],
                composeFocused: false,
                canSendText: false
            )
        } else {
            selectedChatState = nil
        }
    }

    /// Resets all WhatsApp in-memory state (conversation list + cached messages + selection).
    /// Does not touch allow/deny lists (stored elsewhere).
    func resetAll() {
        conversations = []
        chatStatesById.removeAll(keepingCapacity: false)
        selectedConversationId = nil
        selectedChatState = nil

        emit(.conversationsUpdated([]))
        emit(.selectedConversationChanged(nil))
    }

    func chatState(for id: String) -> ChatState? {
        chatStatesById[canonicalChatId(for: id)]
    }

    func conversation(for id: String) -> ConversationSummary? {
        conversations.first(where: { $0.id == canonicalChatId(for: id) })
    }

    func unreadMessages(chatId: String? = nil) -> [Message] {
        messages(
            chatId: chatId,
            onlyUnhandled: true
        )
    }

    func pendingIncomingCount(chatId: String) -> Int {
        guard let state = chatStatesById[canonicalChatId(for: chatId)] else {
            return 0
        }
        return state.messages.filter { $0.direction == .incoming && !$0.isHandled }.count
    }

    func markAllIncomingMessagesHandled(chatId: String? = nil) {
        let now = Date()
        let targets = unreadMessages(chatId: chatId).filter { $0.direction == .incoming }
        let ids = Set(targets.map(\.id))
        guard !ids.isEmpty else { return }
        updateMessages(messageIds: ids, handledAt: now, chatId: chatId)
    }

    func recentMessages(chatId: String, limit: Int) -> [Message] {
        guard let state = chatStatesById[canonicalChatId(for: chatId)] else {
            return []
        }
        return Array(state.messages.suffix(max(1, limit)))
    }

    @discardableResult
    func consumeUnreadMessages(chatId: String? = nil) -> [Message] {
        let now = Date()
        let messageIds = messages(chatId: chatId, onlyUnhandled: true).map(\.id)
        guard !messageIds.isEmpty else {
            return []
        }

        updateMessages(messageIds: Set(messageIds), handledAt: now, chatId: chatId)
        return messages(chatId: chatId, onlyUnhandled: false)
            .filter { messageIds.contains($0.id) }
            .sorted(by: messageSortComparator)
    }

    func markMessagesHandled(messageIds: Set<String>, chatId: String? = nil) {
        guard !messageIds.isEmpty else { return }
        updateMessages(messageIds: messageIds, handledAt: Date(), chatId: chatId)
    }

    func markMessagesUnhandled(messageIds: Set<String>, chatId: String? = nil) {
        guard !messageIds.isEmpty else { return }
        updateMessages(messageIds: messageIds, handledAt: nil, chatId: chatId)
    }

    func markMessageAndFollowingAsUnhandled(messageId: String, chatId: String) {
        let canonicalId = canonicalChatId(for: chatId)
        guard let state = chatStatesById[canonicalId],
              let index = state.messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        let messageIds = Set(
            state.messages[index...]
                .filter { $0.direction == .incoming }
                .map(\.id)
        )
        guard !messageIds.isEmpty else {
            return
        }

        updateMessages(messageIds: messageIds, handledAt: nil, chatId: canonicalId)
    }

    func markMessageAndFollowingAsHandled(messageId: String, chatId: String) {
        let canonicalId = canonicalChatId(for: chatId)
        guard let state = chatStatesById[canonicalId],
              let index = state.messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }

        let messageIds = Set(
            state.messages[index...]
                .filter { $0.direction == .incoming }
                .map(\.id)
        )
        guard !messageIds.isEmpty else {
            return
        }

        updateMessages(messageIds: messageIds, handledAt: Date(), chatId: canonicalId)
    }

    /// Wait indefinitely (no timeout) until a new message arrives.
    func waitForNextMessage(chatId: String?, afterMessageId: String?) async -> WaitForMessageResult? {
        let canonicalRequestedChatId = chatId.map { canonicalChatId(for: $0) }

        if let immediateMatch = latestMessageResult(chatId: canonicalRequestedChatId, afterMessageId: afterMessageId) {
            return immediateMatch
        }

        @MainActor
        final class Waiter {
            var resolved = false
            var listenerId: UUID?
            let continuation: CheckedContinuation<WaitForMessageResult?, Never>
            init(continuation: CheckedContinuation<WaitForMessageResult?, Never>) {
                self.continuation = continuation
            }

            func finish(_ result: WaitForMessageResult?, remove: (UUID) -> Void) {
                guard !resolved else { return }
                resolved = true
                if let listenerId { remove(listenerId) }
                continuation.resume(returning: result)
            }
        }

        return await withCheckedContinuation { continuation in
            let waiter = Waiter(continuation: continuation)

            waiter.listenerId = addEventListener { event in
                guard case .chatStateUpdated(let chatState) = event else {
                    return
                }

                guard canonicalRequestedChatId == nil || chatState.chat.id == canonicalRequestedChatId else {
                    return
                }

                guard let latestMessage = chatState.messages.last else {
                    return
                }

                if let afterMessageId, latestMessage.id == afterMessageId {
                    return
                }

                waiter.finish(WaitForMessageResult(chat: chatState.chat, message: latestMessage), remove: self.removeEventListener)
            }
        }
    }

    @discardableResult
    func addEventListener(_ listener: @escaping (WhatsAppMemoryStoreEvent) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = listener
        return id
    }

    func removeEventListener(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }

    private func emit(_ event: WhatsAppMemoryStoreEvent) {
        for listener in listeners.values {
            listener(event)
        }
    }

    private func normalizeChatState(_ state: ChatState, persistedAt: Date) -> ChatState {
        let sendPrefix = sendPrefixRepository.load()
        let assistantName = sendPrefix.assistantName
        let assistantSignature = sendPrefix.signature

        let messages = state.messages.map { message in
            let ingestedAt = message.ingestedAt ?? persistedAt
            let handledAt = message.handledAt ?? (message.direction == .outgoing ? persistedAt : nil)

            var normalized = message.replacing(ingestedAt: ingestedAt, handledAt: handledAt)
            if normalized.direction == .outgoing, normalized.origin == .unknown {
                normalized = normalized.replacing(origin: inferOutgoingOrigin(
                    message: normalized,
                    assistantName: assistantName,
                    assistantSignature: assistantSignature
                ))
            }
            return normalized
        }
        return state.replacing(messages: messages)
    }

    private func inferOutgoingOrigin(message: Message, assistantName: String, assistantSignature: String) -> MessageOrigin {
        let trimmedAssistantName = assistantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSignature = assistantSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAssistantName.isEmpty || !trimmedSignature.isEmpty else {
            return .unknown
        }

        let raw = (message.text ?? message.rawAccessibilityText)
            .normalizedAXText
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalized = raw.lowercased()

        var looksLikeAssistant = false
        if !trimmedAssistantName.isEmpty {
            let expectedPrefix = "\(trimmedAssistantName):".normalizedAXText
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            looksLikeAssistant = looksLikeAssistant || normalized.hasPrefix(expectedPrefix)
        }
        if !trimmedSignature.isEmpty {
            let expectedSignature = trimmedSignature.normalizedAXText
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            looksLikeAssistant = looksLikeAssistant || normalized.hasSuffix(expectedSignature)
        }

        return looksLikeAssistant ? .assistant : .human
    }

    private func mergeMessages(existing: [Message], incoming: [Message], persistedAt: Date) -> [Message] {
        var merged = existing
        var indexByKey: [String: Int] = [:]
        for (index, message) in merged.enumerated() {
            indexByKey[message.semanticDeduplicationKey] = index
        }

        for message in incoming {
            let key = message.semanticDeduplicationKey
            if let index = indexByKey[key] {
                let current = merged[index]
                merged[index] = mergeMessage(existing: current, incoming: message, persistedAt: persistedAt)
            } else {
                let stored = message.replacing(
                    ingestedAt: message.ingestedAt ?? persistedAt,
                    handledAt: message.handledAt ?? (message.direction == .outgoing ? persistedAt : nil)
                )
                indexByKey[key] = merged.count
                merged.append(stored)
            }
        }

        return merged.sorted(by: messageSortComparator)
    }

    private func mergeMessage(existing: Message, incoming: Message, persistedAt: Date) -> Message {
        let status: MessageStatus = {
            switch (existing.status, incoming.status) {
            case (.unknown, let newStatus):
                return newStatus
            case (let current, .unknown):
                return current
            default:
                return incoming.status
            }
        }()

        let mergedAuthorName = existing.authorName ?? incoming.authorName
        let mergedOrigin: MessageOrigin = {
            switch (existing.origin, incoming.origin) {
            case (.unknown, let newOrigin):
                return newOrigin
            default:
                return existing.origin
            }
        }()

        return existing.replacing(
            authorName: mergedAuthorName,
            origin: mergedOrigin,
            text: incoming.text ?? existing.text,
            durationSeconds: incoming.durationSeconds ?? existing.durationSeconds,
            timestamp: incoming.timestamp ?? existing.timestamp,
            status: status,
            rawAccessibilityText: incoming.rawAccessibilityText.isEmpty ? existing.rawAccessibilityText : incoming.rawAccessibilityText,
            whatsappTimestampText: incoming.whatsappTimestampText ?? existing.whatsappTimestampText,
            ingestedAt: existing.ingestedAt ?? incoming.ingestedAt ?? persistedAt,
            handledAt: existing.handledAt ?? incoming.handledAt ?? (incoming.direction == .outgoing ? persistedAt : nil)
        )
    }

    private func messages(chatId: String?, onlyUnhandled: Bool) -> [Message] {
        let allMessages: [Message]
        if let chatId, let state = chatStatesById[canonicalChatId(for: chatId)] {
            allMessages = state.messages
        } else {
            allMessages = chatStatesById.values.flatMap(\.messages)
        }

        return allMessages
            .filter { onlyUnhandled ? !$0.isHandled : true }
            .sorted(by: messageSortComparator)
    }

    private func updateMessages(messageIds: Set<String>, handledAt: Date?, chatId: String?) {
        let targetChatIds: [String]
        if let chatId {
            targetChatIds = [canonicalChatId(for: chatId)]
        } else {
            targetChatIds = Array(chatStatesById.keys)
        }

        for chatId in targetChatIds {
            guard let state = chatStatesById[chatId] else {
                continue
            }

            let updatedMessages = state.messages.map { message in
                guard messageIds.contains(message.id) else { return message }
                return message.replacing(handledAt: handledAt)
            }

            guard updatedMessages != state.messages else {
                continue
            }

            let updatedState = state.replacing(messages: updatedMessages)
            chatStatesById[chatId] = updatedState
            if selectedConversationId == chatId {
                selectedChatState = updatedState
            }
            emit(.chatStateUpdated(updatedState))
        }
    }

    private func messageSortComparator(_ lhs: Message, _ rhs: Message) -> Bool {
        switch (lhs.ingestedAt, rhs.ingestedAt) {
        case let (left?, right?):
            if left != right { return left < right }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        switch (lhs.timestamp, rhs.timestamp) {
        case let (left?, right?):
            if left != right { return left < right }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return lhs.id < rhs.id
    }

    private func latestMessageResult(chatId: String?, afterMessageId: String?) -> WaitForMessageResult? {
        let candidates: [ChatState]
        if let chatId, let chatState = chatStatesById[canonicalChatId(for: chatId)] {
            candidates = [chatState]
        } else {
            candidates = Array(chatStatesById.values)
        }

        return candidates
            .compactMap { chatState -> WaitForMessageResult? in
                guard let latestMessage = chatState.messages.last else {
                    return nil
                }

                if let afterMessageId, latestMessage.id == afterMessageId {
                    return nil
                }

                return WaitForMessageResult(chat: chatState.chat, message: latestMessage)
            }
            .sorted { lhs, rhs in
                switch (lhs.message.timestamp, rhs.message.timestamp) {
                case let (left?, right?):
                    if left != right { return left > right }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }

                return lhs.message.id > rhs.message.id
            }
            .first
    }

    private func canonicalChatId(for value: String) -> String {
        WhatsAppConversationIdentity.canonicalChatId(for: value)
    }
}
