import Foundation

struct AIProviderFailure: Equatable, Sendable, Encodable {
    let message: String
    let provider: AIConnectionProviderKind?
    let model: String?
    let endpoint: String?
    let statusCode: Int?
    let responseHeaders: [String: String]
    let responseBody: String?
    let requestBody: String?
    let requestMessageCount: Int?
    let requestToolCount: Int?
    let underlyingError: String?

    init(
        message: String,
        provider: AIConnectionProviderKind? = nil,
        model: String? = nil,
        endpoint: String? = nil,
        statusCode: Int? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: String? = nil,
        requestBody: String? = nil,
        requestMessageCount: Int? = nil,
        requestToolCount: Int? = nil,
        underlyingError: String? = nil
    ) {
        self.message = message
        self.provider = provider
        self.model = model
        self.endpoint = endpoint
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.requestBody = requestBody
        self.requestMessageCount = requestMessageCount
        self.requestToolCount = requestToolCount
        self.underlyingError = underlyingError
    }
}
