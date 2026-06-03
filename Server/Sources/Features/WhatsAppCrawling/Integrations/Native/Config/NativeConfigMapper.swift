import Foundation

struct NativeConfigMapper {
    func makeFlowRegistry(from config: CrawlingConfig) -> NativeFlowRegistry {
        NativeFlowRegistry(flows: config.flows)
    }

    func makeExtractionRegistry(from config: CrawlingConfig) -> NativeExtractionRegistry {
        NativeExtractionRegistry(nodes: config.native?.nodes ?? [:])
    }
}
