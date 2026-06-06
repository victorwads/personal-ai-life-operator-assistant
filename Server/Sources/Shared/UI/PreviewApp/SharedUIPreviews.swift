import SwiftUI

struct SharedUIPreviews: View {
    var body: some View {
        DesignSystemPreviewRootView()
    }
}

#Preview("Shared UI") {
    SharedUIPreviews()
        .frame(width: 1280, height: 900)
}
