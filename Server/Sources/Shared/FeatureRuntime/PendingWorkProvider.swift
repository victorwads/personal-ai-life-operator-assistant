import Foundation

protocol PendingWorkProvider {
    func hasPendingWork() async throws -> Bool
}
