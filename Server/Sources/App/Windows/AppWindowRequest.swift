import SwiftUI

struct AppWindowRequest {
    let id: String
    let title: String
    let rootView: AnyView
    let size: CGSize
    let onClose: (() -> Void)?

    init(
        id: String,
        title: String,
        rootView: AnyView,
        size: CGSize = CGSize(width: 760, height: 520),
        onClose: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.rootView = rootView
        self.size = size
        self.onClose = onClose
    }
}
