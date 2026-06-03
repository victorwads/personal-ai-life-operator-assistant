import SwiftUI

struct DSCodeBlock: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(nil)
                .fixedSize(horizontal: true, vertical: true)
                .textSelection(.enabled)
                .frame(alignment: .topLeading)
                .padding(10)
        }
        .lineLimit(nil)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
