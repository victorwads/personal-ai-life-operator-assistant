import Foundation

struct FlowState: Codable, Equatable, Sendable {
    let activeFlowIdentifiers: [String]
    let detectedAt: Date

    init(activeFlowIdentifiers: [String], detectedAt: Date = .init()) {
        self.activeFlowIdentifiers = activeFlowIdentifiers
        self.detectedAt = detectedAt
    }

    var primaryFlowIdentifier: String? {
        activeFlowIdentifiers.first
    }

    func contains(_ flowIdentifier: String) -> Bool {
        activeFlowIdentifiers.contains(flowIdentifier)
    }
}
