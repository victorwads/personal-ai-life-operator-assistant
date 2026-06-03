import Foundation

struct WebConfigMapper {
    func makeActionRegistry(from config: CrawlingConfig) -> WebActionRegistry {
        WebActionRegistry(shortcuts: config.actions?.shortcuts ?? [:])
    }

    func makeFlowRegistry(from config: CrawlingConfig) -> WebFlowRegistry {
        WebFlowRegistry(flows: config.flows)
    }

    func makeExtractionRegistry(from config: CrawlingConfig) -> WebExtractionRegistry {
        WebExtractionRegistry(nodes: config.web?.nodes ?? [:])
    }
}
