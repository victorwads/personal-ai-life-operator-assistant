import Foundation

public final class RealtimeDatabaseListenerToken: @unchecked Sendable {
    private var cancellation: (() -> Void)?

    public init(_ cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    public func cancel() {
        cancellation?()
        cancellation = nil
    }

    deinit {
        cancel()
    }
}
