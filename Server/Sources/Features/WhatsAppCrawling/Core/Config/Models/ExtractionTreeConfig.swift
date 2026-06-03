import Foundation

struct ExtractionTreeConfig: Decodable, Equatable, Sendable {
    let nodes: [String: ExtractionNodeConfig]
}
