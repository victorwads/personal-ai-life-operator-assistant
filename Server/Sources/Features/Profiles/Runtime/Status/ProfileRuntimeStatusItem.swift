import Foundation

@MainActor
struct ProfileRuntimeStatusItem: Identifiable {
    let id: String
    let title: String
    let stateLabel: String
    let detail: String?
    let actionTitle: String?
    let action: (() async -> Void)?
}
