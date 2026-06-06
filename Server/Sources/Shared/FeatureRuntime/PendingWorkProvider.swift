import Foundation

protocol PendingWorkProvider {
    func pendingWorkSection() async throws -> PendingWorkSection?
}
