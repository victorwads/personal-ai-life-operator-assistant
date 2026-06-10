import Foundation

@MainActor
final class GoogleWorkspaceHTTPClient {
    private let authService: GoogleOAuthService

    init(authService: GoogleOAuthService) {
        self.authService = authService
    }

    func get<T: Decodable>(_ urlString: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(method: "GET", urlString: urlString, body: nil as String?, queryItems: queryItems)
    }

    func post<T: Decodable, B: Encodable>(_ urlString: String, body: B?, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(method: "POST", urlString: urlString, body: body, queryItems: queryItems)
    }

    func patch<T: Decodable, B: Encodable>(_ urlString: String, body: B?, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(method: "PATCH", urlString: urlString, body: body, queryItems: queryItems)
    }

    func delete<T: Decodable>(_ urlString: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(method: "DELETE", urlString: urlString, body: nil as String?, queryItems: queryItems)
    }

    func request<T: Decodable, B: Encodable>(
        method: String,
        urlString: String,
        body: B?,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard var components = URLComponents(string: urlString) else {
            throw NSError(domain: "GoogleWorkspaceHTTPClient", code: 201, userInfo: [
                NSLocalizedDescriptionKey: "Invalid URL string."
            ])
        }
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let url = components.url else {
            throw NSError(domain: "GoogleWorkspaceHTTPClient", code: 202, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate URL with query parameters."
            ])
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        return try await performRequest(request)
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        var mutableRequest = request
        let token = try await authService.ensureValidToken()
        mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: mutableRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "GoogleWorkspaceHTTPClient", code: 203, userInfo: [
                    NSLocalizedDescriptionKey: "Response was not a valid HTTP response."
                ])
            }

            if httpResponse.statusCode == 401 {
                // Access token might have been revoked or expired silently.
                // Force a token refresh and retry the request once.
                let newToken = try await authService.forceRefresh()
                mutableRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                
                let (retryData, retryResponse) = try await URLSession.shared.data(for: mutableRequest)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw NSError(domain: "GoogleWorkspaceHTTPClient", code: 203, userInfo: [
                        NSLocalizedDescriptionKey: "Response was not a valid HTTP response."
                    ])
                }

                if !(200...299).contains(retryHttpResponse.statusCode) {
                    throw makeAPIError(statusCode: retryHttpResponse.statusCode, data: retryData)
                }

                if retryHttpResponse.statusCode == 204 || retryData.isEmpty {
                    if let empty = GoogleEmptyResponse() as? T {
                        return empty
                    }
                    let emptyData = "{}".data(using: .utf8)!
                    return try JSONDecoder().decode(T.self, from: emptyData)
                }

                return try JSONDecoder().decode(T.self, from: retryData)
            }

            if !(200...299).contains(httpResponse.statusCode) {
                throw makeAPIError(statusCode: httpResponse.statusCode, data: data)
            }

            if httpResponse.statusCode == 204 || data.isEmpty {
                if let empty = GoogleEmptyResponse() as? T {
                    return empty
                }
                let emptyData = "{}".data(using: .utf8)!
                return try JSONDecoder().decode(T.self, from: emptyData)
            }

            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw redactTokenFromError(error)
        }
    }

    private func makeAPIError(statusCode: Int, data: Data) -> Error {
        let errorDetails = String(data: data, encoding: .utf8) ?? "Unknown response details"
        // Ensure we don't accidentally leak tokens in API error details if the server returns them in error payload
        let redactedDetails = redactTokens(in: errorDetails)
        
        return NSError(domain: "GoogleWorkspaceHTTPClient", code: 204, userInfo: [
            NSLocalizedDescriptionKey: "Google API call failed with status code \(statusCode): \(redactedDetails)"
        ])
    }

    private func redactTokenFromError(_ error: Error) -> Error {
        let nsError = error as NSError
        var userInfo = nsError.userInfo
        if let description = userInfo[NSLocalizedDescriptionKey] as? String {
            userInfo[NSLocalizedDescriptionKey] = redactTokens(in: description)
        }
        return NSError(domain: nsError.domain, code: nsError.code, userInfo: userInfo)
    }

    func redactTokens(in text: String) -> String {
        // Redact OAuth Bearer tokens, refresh tokens, and basic authorization headers
        var redacted = text
        
        // Match standard bearer tokens
        if let regex = try? NSRegularExpression(pattern: "(ya29\\.[a-zA-Z0-9_\\-]+)", options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            redacted = regex.stringByReplacingMatches(in: redacted, options: [], range: range, withTemplate: "[ACCESS_TOKEN_REDACTED]")
        }
        
        // Match refresh tokens (typically 1//... or similar)
        if let regex = try? NSRegularExpression(pattern: "(1//[a-zA-Z0-9_\\-]+)", options: .caseInsensitive) {
            let range = NSRange(redacted.startIndex..., in: redacted)
            redacted = regex.stringByReplacingMatches(in: redacted, options: [], range: range, withTemplate: "[REFRESH_TOKEN_REDACTED]")
        }

        return redacted
    }
}

struct GoogleEmptyResponse: Codable, Sendable {}
