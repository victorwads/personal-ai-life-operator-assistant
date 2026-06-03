import Foundation

final class NativeWhatsAppIntegration: WhatsAppCrawlingIntegration {
    private let config: CrawlingConfig
    private let runtime: AccessibilityRuntime
    private let flowRegistry: NativeFlowRegistry
    private let extractionRegistry: NativeExtractionRegistry

    init(
        config: CrawlingConfig,
        runtime: AccessibilityRuntime,
        configMapper: NativeConfigMapper = NativeConfigMapper()
    ) {
        self.config = config
        self.runtime = runtime
        self.flowRegistry = configMapper.makeFlowRegistry(from: config)
        self.extractionRegistry = configMapper.makeExtractionRegistry(from: config)
    }

    func resolveFlowState() async -> CrawlingResult<FlowState> {
        let parser = NativeFlowParser(registry: flowRegistry, runtime: runtime)
        return await parser.parse(ParserContext(config: flowRegistry, flowState: FlowState(activeFlowIdentifiers: []), runtime: runtime))
    }

    func listChats() async -> CrawlingResult<[CrawledChat]> {
        let parser = NativeChatListParser(registry: extractionRegistry, runtime: runtime)
        return await parser.parse(ParserContext(config: extractionRegistry, flowState: FlowState(activeFlowIdentifiers: []), runtime: runtime))
    }

    func selectChat(_ chat: CrawledChat) async -> CrawlingResult<Void> {
        let interactor = NativeSelectChatInteractor(runtime: runtime)
        return await interactor.execute(chat)
    }

    func listMessages() async -> CrawlingResult<[CrawledMessage]> {
        let parser = NativeMessageListParser(registry: extractionRegistry, runtime: runtime)
        return await parser.parse(ParserContext(config: extractionRegistry, flowState: FlowState(activeFlowIdentifiers: []), runtime: runtime))
    }

    func sendMessage(_ input: SendMessageInput) async -> CrawlingResult<Void> {
        let interactor = NativeSendMessageInteractor(runtime: runtime)
        return await interactor.execute(input)
    }

    func archiveChat(_ chat: CrawledChat) async -> CrawlingResult<Void> {
        let interactor = NativeArchiveChatInteractor(runtime: runtime)
        return await interactor.execute(chat)
    }
}
