import Foundation

public struct Profile: FirebasePersistableModel, Equatable, Sendable {
    public var id: String?
    public var ownerUid: String?
    public var name: String
    public var mcpPort: Int
    public var autoStart: Bool

    public init(
        id: String? = nil,
        ownerUid: String? = nil,
        name: String,
        mcpPort: Int,
        autoStart: Bool = false
    ) {
        self.id = id
        self.ownerUid = ownerUid
        self.name = name
        self.mcpPort = mcpPort
        self.autoStart = autoStart
    }
}
