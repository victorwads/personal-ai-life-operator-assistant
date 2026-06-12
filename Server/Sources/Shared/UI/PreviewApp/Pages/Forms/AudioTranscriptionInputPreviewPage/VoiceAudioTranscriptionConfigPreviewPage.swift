import SwiftUI

struct VoiceAudioTranscriptionConfigPreviewPage: View {
    @State private var config = VoiceAudioTranscriptionConfig.default

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Audio Transcription Config",
                    subtitle: "Dedicated preview for the reusable voice transcription settings form."
                ) {
                    VoiceAudioTranscriptionConfigForm(
                        config: $config,
                        showsFilePickers: true
                    )
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
