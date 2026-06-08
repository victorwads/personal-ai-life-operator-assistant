import Foundation

struct AIResourceUsageDocument: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?

    var total: AIResourceTokenUsage
    var assistant: AIResourceTokenUsage
    var imageExtraction: AIResourceTokenUsage

    init(
        id: String? = "usage",
        total: AIResourceTokenUsage = AIResourceTokenUsage(),
        assistant: AIResourceTokenUsage = AIResourceTokenUsage(),
        imageExtraction: AIResourceTokenUsage = AIResourceTokenUsage()
    ) {
        self.id = id
        self.total = total
        self.assistant = assistant
        self.imageExtraction = imageExtraction
    }
}
