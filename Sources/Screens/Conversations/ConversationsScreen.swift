import SwiftUI

struct ConversationsScreen: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Conversations")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(appModel.conversations.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ForEach(appModel.conversations) { conversation in
                        Button {
                            open(conversation)
                        } label: {
                            ConversationRow(conversation: conversation)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 4)
                                .background(selectionBackground(for: conversation))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)

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

    @ViewBuilder
    private func selectionBackground(for conversation: ConversationSummary) -> some View {
        if appModel.selectedConversationId == conversation.id {
            Color.accentColor.opacity(0.22)
        } else {
            Color.clear
        }
    }
}

