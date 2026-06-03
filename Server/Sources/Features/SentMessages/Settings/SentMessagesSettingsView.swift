import SwiftUI

struct SentMessagesSettingsView: View {
    let wrapper: SentMessagesSettingsWrapper

    @State private var assistantName = ""
    @State private var messagePrefix = ""
    @State private var messagePostfix = ""
    @State private var messageHeader = ""
    @State private var messageFooter = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current send order: header as its own first message, then each message with prefix and postfix applied, then footer as its own last message.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DSSettingsTextField(
                title: "Assistant Name",
                prompt: "Assistant",
                helperText: "Used as the configured outbound assistant identity. It does not add text to the message body itself.",
                text: assistantNameBinding
            )

            DSSettingsTextField(
                title: "Message Header",
                prompt: "Optional first message",
                helperText: "If filled, this is sent as a separate first message before the main batch.",
                text: messageHeaderBinding
            )

            DSSettingsTextField(
                title: "Message Prefix",
                prompt: "Optional text before each message",
                helperText: "Added to the start of every main message in the batch, not just the first one.",
                text: messagePrefixBinding
            )

            DSSettingsTextField(
                title: "Message Postfix",
                prompt: "Optional text after each message",
                helperText: "Added to the end of every main message in the batch.",
                text: messagePostfixBinding
            )

            DSSettingsTextField(
                title: "Message Footer",
                prompt: "Optional last message",
                helperText: "If filled, this is sent as a separate last message after the main batch.",
                text: messageFooterBinding
            )

            Text("Empty values mean no extra formatting is applied.")
                .foregroundStyle(.secondary)
        }
        .task {
            assistantName = wrapper.assistantName
            messagePrefix = wrapper.messagePrefix
            messagePostfix = wrapper.messagePostfix
            messageHeader = wrapper.messageHeader
            messageFooter = wrapper.messageFooter
        }
    }

    private var assistantNameBinding: Binding<String> {
        Binding {
            assistantName
        } set: { value in
            assistantName = value
            wrapper.assistantName = value
        }
    }

    private var messagePrefixBinding: Binding<String> {
        Binding {
            messagePrefix
        } set: { value in
            messagePrefix = value
            wrapper.messagePrefix = value
        }
    }

    private var messagePostfixBinding: Binding<String> {
        Binding {
            messagePostfix
        } set: { value in
            messagePostfix = value
            wrapper.messagePostfix = value
        }
    }

    private var messageHeaderBinding: Binding<String> {
        Binding {
            messageHeader
        } set: { value in
            messageHeader = value
            wrapper.messageHeader = value
        }
    }

    private var messageFooterBinding: Binding<String> {
        Binding {
            messageFooter
        } set: { value in
            messageFooter = value
            wrapper.messageFooter = value
        }
    }
}
