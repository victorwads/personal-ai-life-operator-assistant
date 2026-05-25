import Foundation

enum MCPToolTrait: String, Codable, Equatable, Sendable, CaseIterable {
    case readOnly = "read-only"
    case writesState = "write-state"
    case sideEffect = "side-effect"
    case blocking = "blocking"
}
