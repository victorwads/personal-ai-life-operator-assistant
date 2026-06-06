import SwiftUI

struct AudioTranscriptionPreviewCase: View {
    let title: String
    let mode: DSAudioTranscriptionInputMode
    let placeholder: String
    let config: DSAudioTranscriptionInputConfig

    @State private var text: String
    @StateObject private var controller: FakeAudioTranscriptionController

    init(
        title: String,
        mode: DSAudioTranscriptionInputMode,
        initialText: String,
        controller: FakeAudioTranscriptionController,
        placeholder: String,
        config: DSAudioTranscriptionInputConfig = .init()
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
                mode: mode,
                text: $text,
                controller: controller,
                placeholder: placeholder,
                config: config
            )
        }
    }
}
