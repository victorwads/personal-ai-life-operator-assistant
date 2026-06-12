import SwiftUI

struct AudioTranscriptionPreviewCase: View {
    let title: String
    let mode: DSAudioTranscriptionInputMode
    let placeholder: String
    let config: DSAudioTranscriptionInputConfig

    @State private var text: String
    @StateObject private var controller: DSAudioTranscriptionInputPreviewController

    init(
        title: String,
        mode: DSAudioTranscriptionInputMode,
        initialText: String,
        controller: DSAudioTranscriptionInputPreviewController,
        placeholder: String,
        config: DSAudioTranscriptionInputConfig = .default
    ) {
        self.title = title
        self.mode = mode
        self.placeholder = placeholder
        self.config = config
        _text = State(initialValue: initialText)
        _controller = StateObject(wrappedValue: controller)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            DSAudioTranscriptionInput(
                title: "Message",
                placeholder: placeholder,
                mode: mode,
                text: $text,
                controller: controller,
                config: config
            )
        }
    }
}
