import Foundation

@MainActor
protocol AIConnectionToolCataloging {
    func listTools() -> [AIToolDefinition]
}
