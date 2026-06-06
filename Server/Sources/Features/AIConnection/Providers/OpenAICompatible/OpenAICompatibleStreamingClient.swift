import Foundation

struct OpenAICompatibleStreamingClient {
    let configuration: AIConnectionProviderConfiguration
    let urlSession: URLSession
    let providerExchangeLogger: @Sendable (AIConnectionErrorLogStore.ProviderExchangeLogPayload) -> Void

    init(
        configuration: AIConnectionProviderConfiguration,
        urlSession: URLSession? = nil,
        providerExchangeLogger: @escaping @Sendable (AIConnectionErrorLogStore.ProviderExchangeLogPayload) -> Void = { _ in }
    ) {
        self.configuration = configuration
        self.urlSession = urlSession ?? Self.makeURLSession()
        self.providerExchangeLogger = providerExchangeLogger
    }

    func streamEvents(
        for request: AIProviderRequest
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var failureContext: OpenAICompatibleFailureContext?
                var responseHeaders: [String: String] = [:]
                var rawResponseLines: [String] = []
                do {
                    var parser = OpenAICompatibleStreamParser(
                        provider: configuration.providerKind,
                        requestedModel: request.model
                    )
                    continuation.yield(
                        .requestStarted(provider: configuration.providerKind, model: request.model)
                    )

                    let urlRequest = try makeURLRequest(for: request)
                    failureContext = OpenAICompatibleFailureContext(
                        provider: configuration.providerKind,
                        model: request.model,
                        endpoint: urlRequest.url?.absoluteString,
                        requestBody: Self.httpBodyString(from: urlRequest),
                        requestMessageCount: request.messages.count,
                        requestToolCount: request.tools.count
                    )
                    let (bytes, response) = try await urlSession.bytes(for: urlRequest)
                    try await validate(
                        response: response,
                        bytes: bytes,
                        failureContext: failureContext
                    )
                    if let httpResponse = response as? HTTPURLResponse {
                        responseHeaders = Self.responseHeaders(from: httpResponse)
                    }

                    for try await line in bytes.lines {
                        rawResponseLines.append(line)
                        let events = try parser.parse(line: line)
                        for event in events {
                            continuation.yield(event)
                        }
                    }

                    providerExchangeLogger(
                        AIConnectionErrorLogStore.ProviderExchangeLogPayload(
                            recordedAt: Date(),
                            provider: configuration.providerKind.rawValue,
                            model: request.model,
                            endpoint: failureContext?.endpoint,
                            statusCode: 200,
                            requestBody: failureContext?.requestBody,
                            responseBody: rawResponseLines.joined(separator: "\n"),
                            responseHeaders: responseHeaders,
                            outcome: "succeeded",
                            underlyingError: nil
                        )
                    )
                    continuation.finish()
                } catch {
                    let providerFailure = Self.providerFailure(from: error, fallback: failureContext)
                    providerExchangeLogger(
                        AIConnectionErrorLogStore.ProviderExchangeLogPayload(
                            recordedAt: Date(),
                            provider: providerFailure.provider?.rawValue ?? configuration.providerKind.rawValue,
                            model: providerFailure.model ?? request.model,
                            endpoint: providerFailure.endpoint ?? failureContext?.endpoint,
                            statusCode: providerFailure.statusCode,
                            requestBody: providerFailure.requestBody ?? failureContext?.requestBody,
                            responseBody: providerFailure.responseBody,
                            responseHeaders: providerFailure.responseHeaders,
                            outcome: "failed",
                            underlyingError: providerFailure.underlyingError
                        )
                    )
                    continuation.yield(.failed(providerFailure))
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeURLRequest(for request: AIProviderRequest) throws -> URLRequest {
        let endpoint = try endpointURL()
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let trimmedAPIKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAPIKey.isEmpty {
            urlRequest.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = OpenAICompatibleChatCompletionsRequest(request: request)
        urlRequest.httpBody = try JSONEncoder().encode(payload)
        return urlRequest
    }

    private func endpointURL() throws -> URL {
        let trimmedBaseURL = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else {
            throw OpenAICompatibleStreamingClientError.missingBaseURL
        }

        guard var components = URLComponents(string: trimmedBaseURL) else {
            throw OpenAICompatibleStreamingClientError.invalidBaseURL(trimmedBaseURL)
        }

        // TODO: Normalize base URLs that already include `/chat/completions`.
        // Today `https://host/v1/chat/completions` would become `/v1/chat/completions/chat/completions`.
        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + normalizedPath + "/chat/completions"

        guard let url = components.url else {
            throw OpenAICompatibleStreamingClientError.invalidBaseURL(trimmedBaseURL)
        }

        return url
    }

    private func validate(
        response: URLResponse,
        bytes: URLSession.AsyncBytes,
        failureContext: OpenAICompatibleFailureContext?
    ) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAICompatibleStreamingClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenAICompatibleStreamingClientError.unsuccessfulStatusCode(
                statusCode: httpResponse.statusCode,
                endpoint: failureContext?.endpoint,
                responseHeaders: Self.responseHeaders(from: httpResponse),
                responseBody: try await Self.collectResponseBody(from: bytes),
                provider: failureContext?.provider,
                model: failureContext?.model,
                requestBody: failureContext?.requestBody,
                requestMessageCount: failureContext?.requestMessageCount,
                requestToolCount: failureContext?.requestToolCount
            )
        }
    }

    private static func providerFailure(
        from error: Error,
        fallback: OpenAICompatibleFailureContext?
    ) -> AIProviderFailure {
        if let error = error as? OpenAICompatibleStreamingClientError {
            return error.providerFailure
        }

        return AIProviderFailure(
            message: error.localizedDescription,
            provider: fallback?.provider,
            model: fallback?.model,
            endpoint: fallback?.endpoint,
            requestBody: fallback?.requestBody,
            requestMessageCount: fallback?.requestMessageCount,
            requestToolCount: fallback?.requestToolCount,
            underlyingError: String(describing: error)
        )
    }

    private static func httpBodyString(from request: URLRequest) -> String? {
        guard let httpBody = request.httpBody else { return nil }
        return String(data: httpBody, encoding: .utf8)
    }

    private static func responseHeaders(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [String: String]()) { partialResult, entry in
            partialResult[String(describing: entry.key)] = String(describing: entry.value)
        }
    }

    private static func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60 * 60 * 24
        configuration.timeoutIntervalForResource = 60 * 60 * 24 * 7
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }

    private static func collectResponseBody(
        from bytes: URLSession.AsyncBytes,
        limit: Int = 64 * 1024
    ) async throws -> String? {
        var data = Data()
        for try await byte in bytes {
            if data.count >= limit {
                break
            }
            data.append(byte)
        }

        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8) ?? data.base64EncodedString()
    }
}

private enum OpenAICompatibleStreamingClientError: LocalizedError {
    case missingBaseURL
    case invalidBaseURL(String)
    case invalidResponse
    case unsuccessfulStatusCode(
        statusCode: Int,
        endpoint: String?,
        responseHeaders: [String: String],
        responseBody: String?,
        provider: AIConnectionProviderKind?,
        model: String?,
        requestBody: String?,
        requestMessageCount: Int?,
        requestToolCount: Int?
    )

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "AI Connection base URL is required for streaming requests."
        case let .invalidBaseURL(baseURL):
            return "AI Connection base URL is invalid: \(baseURL)"
        case .invalidResponse:
            return "AI provider returned a non-HTTP response."
        case let .unsuccessfulStatusCode(statusCode, _, _, _, _, _, _, _, _):
            return "AI provider request failed with status code \(statusCode)."
        }
    }

    var providerFailure: AIProviderFailure {
        switch self {
        case .missingBaseURL, .invalidBaseURL, .invalidResponse:
            return AIProviderFailure(
                message: errorDescription ?? "AI provider request failed.",
                underlyingError: String(describing: self)
            )
        case let .unsuccessfulStatusCode(
            statusCode,
            endpoint,
            responseHeaders,
            responseBody,
            provider,
            model,
            requestBody,
            requestMessageCount,
            requestToolCount
        ):
            return AIProviderFailure(
                message: errorDescription ?? "AI provider request failed with status code \(statusCode).",
                provider: provider,
                model: model,
                endpoint: endpoint,
                statusCode: statusCode,
                responseHeaders: responseHeaders,
                responseBody: responseBody,
                requestBody: requestBody,
                requestMessageCount: requestMessageCount,
                requestToolCount: requestToolCount,
                underlyingError: String(describing: self)
            )
        }
    }
}

private struct OpenAICompatibleFailureContext {
    let provider: AIConnectionProviderKind
    let model: String
    let endpoint: String?
    let requestBody: String?
    let requestMessageCount: Int
    let requestToolCount: Int
}
