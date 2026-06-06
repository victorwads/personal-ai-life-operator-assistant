import SwiftUI

struct CodeBlocksPreviewPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PreviewSection(
                    title: "Code Blocks",
                    subtitle: "Formatted payloads, snippets, and structured text."
                ) {
                    DSCodeBlock(
                        """
                        # Client memories

                        ## key: client_language
                        pt-BR

                        ---

                        ## key: client_identity
                        Victor
                        """
                    )
                    .frame(height: 96)
                }
            }
            .previewBounds()
            .padding(24)
        }
    }
}
