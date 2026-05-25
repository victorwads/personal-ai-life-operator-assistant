import Foundation

protocol MCPToolProvider {
    var group: MCPToolGroup { get }
    var tools: [any MCPToolHandler.Type] { get }
}
