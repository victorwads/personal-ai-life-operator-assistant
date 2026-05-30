import SwiftUI

struct MCPToolPayloadPreview: View {
    let payload: String

    var body: some View {
        MCPToolCodeSection(title: "Generated Payload", code: payload)
    }
}
