import Foundation

// TODO: Replace the current ChatHeaderParser + MessageListParser split with a
// CurrentChatParser that returns a CrawledChatSnapshot for the selected chat.
protocol CurrentChatParser: CrawlingParser where Output == CrawledChatSnapshot {}
