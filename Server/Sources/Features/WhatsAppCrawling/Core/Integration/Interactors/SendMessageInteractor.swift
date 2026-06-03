import Foundation

protocol SendMessageInteractor: CrawlingInteractor where Input == SendMessageInput, Output == Void {}
