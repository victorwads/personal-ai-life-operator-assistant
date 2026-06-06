import Foundation

struct PendingWorkSnapshot: Sendable, Equatable {
    let sections: [PendingWorkSection]

    var isEmpty: Bool {
        sections.isEmpty
    }
}
