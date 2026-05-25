import Foundation

struct MCPServerContext: Sendable {
    let requestID: String?
    let userInfo: [String: String]

    init(requestID: String? = nil, userInfo: [String: String] = [:]) {
        self.requestID = requestID
        self.userInfo = userInfo
    }
}
