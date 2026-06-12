import SwiftUI

struct AudioTranscriptionInputPreviewPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PreviewSection(
                title: "Audio Transcription Input",
                subtitle: "Editable final text stays inline with temporary non-editable transcription badges."
            ) {
                DSAudioTranscriptionInputPreviewCatalog()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .previewBounds()
        .padding(24)
        .frame(minWidth: 360, idealWidth: 720, maxWidth: .infinity, alignment: .leading)
    }
}
