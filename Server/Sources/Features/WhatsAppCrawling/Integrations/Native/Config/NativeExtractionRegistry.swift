import Foundation

struct NativeExtractionRegistry {
    let nodes: [String: ExtractionNodeConfig]

    func node(named name: String) -> ExtractionNodeConfig? {
        nodes[name]
    }
}
