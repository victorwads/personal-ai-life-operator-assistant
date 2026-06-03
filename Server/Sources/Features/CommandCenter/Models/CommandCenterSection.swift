import Foundation

struct CommandCenterSection: Identifiable, Hashable {
    let id: String
    let title: String
    let items: [CommandCenterMenuItem]

    init(id: String, title: String, items: [CommandCenterMenuItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}
