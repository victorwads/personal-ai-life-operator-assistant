import Foundation

/// A debug-only snapshot of relevant DOM regions for WhatsApp Web parsing.
/// This is intentionally "raw" HTML so we can iterate on selectors quickly.
struct WhatsAppWebDebugDOMSnapshot: Codable, Equatable {
    let chatListHTML: String?
    let conversationPanelWrapperHTML: String?
    let conversationHeaderTitleHTML: String?
    let conversationPanelBodyHTML: String?
}

