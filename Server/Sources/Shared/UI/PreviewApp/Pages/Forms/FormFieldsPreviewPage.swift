import SwiftUI

struct FormFieldsPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Text Fields",
                    subtitle: "Shared text inputs used across settings and forms."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        DSSettingsTextField(
                            title: "Message Header",
                            prompt: "Optional first message",
                            helperText: "If filled, this is sent as a separate first message before the main batch.",
                            text: .constant("Oi! Aqui vai um resumo antes da mensagem principal.")
                        )

                        DSSettingsTextField(
                            title: "Message Prefix",
                            prompt: "Optional text before each message",
                            helperText: "Added to the start of every main message in the batch, not just the first one.",
                            text: .constant("[Assistente] ")
                        )
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
