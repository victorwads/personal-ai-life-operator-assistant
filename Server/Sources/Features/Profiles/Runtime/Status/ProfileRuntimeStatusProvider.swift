import Foundation

@MainActor
protocol ProfileRuntimeStatusProvider {
    func statusItems() -> [ProfileRuntimeStatusItem]
}
