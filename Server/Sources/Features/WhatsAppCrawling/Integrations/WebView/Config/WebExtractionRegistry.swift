import Foundation

struct WebExtractionRegistry {
    let nodes: [String: ExtractionNodeConfig]

    func node(named name: String) -> ExtractionNodeConfig? {
        nodes[name]
    }
}
