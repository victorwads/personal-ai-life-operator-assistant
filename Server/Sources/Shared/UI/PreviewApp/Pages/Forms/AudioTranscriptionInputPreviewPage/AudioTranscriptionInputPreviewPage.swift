import SwiftUI

struct AudioTranscriptionInputPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Audio Transcription Input",
                    subtitle: "Editable confirmed text stays separate from live and processing transcript state."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        AudioTranscriptionPreviewCase(
                            title: "Textarea Idle",
                            mode: .textarea,
                            initialText: "",
                            controller: FakeAudioTranscriptionController.idle(),
                            placeholder: "Type or speak..."
                        )

                        AudioTranscriptionPreviewCase(
                            title: "Textarea Listening",
                            mode: .textarea,
                            initialText: "Confirmed text stays editable here.",
                            controller: FakeAudioTranscriptionController.listening(),
                            placeholder: "Type or speak...",
                            config: DSAudioTranscriptionInputConfig(autoStartOnFocus: true)
                        )

                        AudioTranscriptionPreviewCase(
                            title: "Textarea Processing",
                            mode: .textarea,
                            initialText: "The client asked for the latest issue summary.",
                            controller: FakeAudioTranscriptionController.processing(),
                            placeholder: "Type or speak..."
                        )

                        AudioTranscriptionPreviewCase(
                            title: "Input Mode",
                            mode: .input,
                            initialText: "This text will receive appended final segments.",
                            controller: FakeAudioTranscriptionController.completedWaitingToAppend(),
                            placeholder: "Type or speak...",
                            config: DSAudioTranscriptionInputConfig(showsSegments: false)
                        )

                        AudioTranscriptionPreviewCase(
                            title: "Failed State",
                            mode: .textarea,
                            initialText: "",
                            controller: FakeAudioTranscriptionController.failed(),
                            placeholder: "Type or speak..."
                        )
                    }
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
