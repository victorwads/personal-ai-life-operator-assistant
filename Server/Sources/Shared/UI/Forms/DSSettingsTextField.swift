import SwiftUI

struct DSSettingsTextField: View {
    let title: String
    let prompt: String
    let helperText: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            TextField(prompt, text: $text)
                .textFieldStyle(.roundedBorder)

            if !helperText.isEmpty {
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
