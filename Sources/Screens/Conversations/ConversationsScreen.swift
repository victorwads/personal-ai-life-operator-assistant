import SwiftUI

struct ConversationsScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedId: ConversationSummary.ID?
    @FocusState private var listFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedId) {
                Section {
                    ForEach(appModel.conversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .tag(conversation.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedId = conversation.id
                                listFocused = true
                                open(conversation)
                            }
                    }
                } header: {
                    HStack {
                        Text("Conversations")
                        Spacer()
                        Text("\(appModel.conversations.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if !appModel.blockedConversationNames.isEmpty {
                    Section("Ignored") {
                        ForEach(appModel.blockedConversationNames, id: \.self) { ignoredName in
                            Text(ignoredName)
                                .lineLimit(1)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                guard appModel.blockedConversationNames.indices.contains(index) else { continue }
                                appModel.unblockConversation(named: appModel.blockedConversationNames[index])
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .focused($listFocused)
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
            .onAppear {
                selectedId = appModel.selectedConversationId
            }
            .onChange(of: appModel.selectedConversationId) { _, newValue in
                if selectedId != newValue {
                    selectedId = newValue
                }
            }

            Divider()

            ChatDetailView(
                chatState: appModel.selectedChatState,
                messageDraft: $appModel.messageDraft,
                isSendingMessage: appModel.isSendingMessage,
                isBlocked: appModel.selectedChatState.map { appModel.isBlocked($0.chat.name) } ?? false,
                onToggleBlocked: {
                    guard let conversationName = appModel.selectedChatState?.chat.name else {
                        return
                    }

                    appModel.toggleBlockedConversation(conversationName)
                },
                onSend: {
                    Task {
                        await appModel.sendMessageToSelectedChat()
                    }
                }
            )
        }
    }

    private func open(_ conversation: ConversationSummary) {
        guard appModel.selectedConversationId != conversation.id else {
            return
        }

        appModel.openConversation(conversation)
    }

    // Ignored conversations are managed via the sidebar section (swipe-to-delete / delete key).
}
