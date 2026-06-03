import Foundation

struct NativeFlowRegistry {
    let flows: [String: FlowConfig]

    func flow(named name: String) -> FlowConfig? {
        flows[name]
    }
}
