import Foundation

protocol WhatsAppCrawlingIntegration {
    func resolveFlowState() async -> CrawlingResult<FlowState>
    func listChats() async -> CrawlingResult<[CrawledChat]>
    func selectChat(_ chat: CrawledChat) async -> CrawlingResult<Void>
    func listMessages() async -> CrawlingResult<[CrawledMessage]>
    func sendMessage(_ input: SendMessageInput) async -> CrawlingResult<Void>
    func archiveChat(_ chat: CrawledChat) async -> CrawlingResult<Void>
}
