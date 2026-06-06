import Foundation

struct PendingWorkSection: Sendable, Equatable {
    let title: String
    let lines: [String]

    var isEmpty: Bool {
        lines.isEmpty
    }
}
