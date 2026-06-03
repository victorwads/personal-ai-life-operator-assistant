import Foundation

struct WebFlowRegistry {
    let flows: [String: FlowConfig]

    func flow(named name: String) -> FlowConfig? {
        flows[name]
    }
}
