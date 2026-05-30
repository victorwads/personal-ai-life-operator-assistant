import Foundation

protocol MCPToolProvider {
    var group: MCPToolGroup { get }
    var tools: [MCPToolHandler.Type] { get }
}

extension MCPToolProvider {
    var toolRegistrations: [MCPToolRegistration] {
        tools.map { handlerType in
            MCPToolRegistration(
                definition: handlerType.definition,
                makeHandler: { handlerType.init() }
            )
        }
    }
}
