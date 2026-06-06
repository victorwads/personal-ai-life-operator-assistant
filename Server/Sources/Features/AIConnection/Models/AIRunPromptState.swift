import Foundation

struct AIRunPromptState {
    let sections: [AIRunPromptSection]
}

struct AIRunPromptSection: Equatable {
    let title: String
    let roleLabel: String
    let content: String
}
