import Foundation

struct MemoriesMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .memories
    private let repository: FirestoreMemoryRepository?

    init(repository: FirestoreMemoryRepository? = nil) {
        self.repository = repository
    }

    var tools: [MCPToolHandler.Type] {
        [
            CreateMemoryTool.self,
            GetMemoryTool.self,
            ListMemoriesTool.self,
            SearchMemoriesTool.self,
            DeleteMemoryTool.self,
        ]
    }

    var toolRegistrations: [MCPToolRegistration] {
        [
            MCPToolRegistration(
                definition: CreateMemoryTool.definition,
                makeHandler: { CreateMemoryTool(repository: repository) }
            ),
            MCPToolRegistration(
                definition: GetMemoryTool.definition,
                makeHandler: { GetMemoryTool(repository: repository) }
            ),
            MCPToolRegistration(
                definition: ListMemoriesTool.definition,
                makeHandler: { ListMemoriesTool(repository: repository) }
            ),
            MCPToolRegistration(
                definition: SearchMemoriesTool.definition,
                makeHandler: { SearchMemoriesTool(repository: repository) }
            ),
            MCPToolRegistration(
                definition: DeleteMemoryTool.definition,
                makeHandler: { DeleteMemoryTool(repository: repository) }
            ),
        ]
    }
}
