import Foundation

struct OpenAICompatibleStreamingClient {
    let configuration: AIConnectionProviderConfiguration
    let urlSession: URLSession

    init(
        configuration: AIConnectionProviderConfiguration,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    func streamEvents(
        for request: AIProviderRequest
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var parser = OpenAICompatibleStreamParser(
                        provider: configuration.providerKind,
                        requestedModel: request.model
                    )
                    continuation.yield(
                        .requestStarted(provider: configuration.providerKind, model: request.model)
                    )

                    let urlRequest = try makeURLRequest(for: request)
                    let (bytes, response) = try await urlSession.bytes(for: urlRequest)
                    try validate(response: response)

                    for try await line in bytes.lines {
                        let events = try parser.parse(line: line)
                        for event in events {
                            continuation.yield(event)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
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

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAICompatibleStreamingClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenAICompatibleStreamingClientError.unsuccessfulStatusCode(httpResponse.statusCode)
        }
    }
}

private enum OpenAICompatibleStreamingClientError: LocalizedError {
    case missingBaseURL
    case invalidBaseURL(String)
    case invalidResponse
    case unsuccessfulStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "AI Connection base URL is required for streaming requests."
        case let .invalidBaseURL(baseURL):
            return "AI Connection base URL is invalid: \(baseURL)"
        case .invalidResponse:
            return "AI provider returned a non-HTTP response."
        case let .unsuccessfulStatusCode(statusCode):
            return "AI provider request failed with status code \(statusCode)."
        }
    }
}
