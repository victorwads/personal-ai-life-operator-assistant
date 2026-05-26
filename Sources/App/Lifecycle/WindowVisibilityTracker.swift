import Foundation

@MainActor
public final class WindowVisibilityTracker: ObservableObject {
    @Published public private(set) var visibleWindowIds: Set<String> = []

    public init() {}

    public var hasVisibleWindows: Bool { !visibleWindowIds.isEmpty }

    public func setVisible(_ visible: Bool, windowId: String) {
        if visible {
            visibleWindowIds.insert(windowId)
        } else {
            visibleWindowIds.remove(windowId)
        }
    }

    public func clear() {
        visibleWindowIds.removeAll()
    }
}

