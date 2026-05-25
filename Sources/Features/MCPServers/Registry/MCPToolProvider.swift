import Foundation

protocol MCPToolProvider {
    var group: MCPToolGroup { get }
    var tools: [MCPToolHandler.Type] { get }
}
