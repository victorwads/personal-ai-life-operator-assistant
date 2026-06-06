import SwiftUI

extension View {
    func previewBounds(maxWidth: CGFloat = 760) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
    }
}
