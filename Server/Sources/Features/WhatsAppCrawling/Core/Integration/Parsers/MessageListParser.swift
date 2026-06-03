import Foundation

protocol MessageListParser: CrawlingParser where Output == [CrawledMessage] {}
