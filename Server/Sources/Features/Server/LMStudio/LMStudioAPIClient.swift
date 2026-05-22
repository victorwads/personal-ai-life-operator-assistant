import Foundation

enum LMStudioClientError: LocalizedError {
    case invalidBaseURL(String)
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case invalidPayload
    case missingFinalResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            return "Invalid LM Studio base URL: \(value)"
        case .invalidResponse:
            return "LM Studio returned an invalid response."
        case .httpError(let statusCode, let body):
            if body.isEmpty {
                return "LM Studio request failed with HTTP \(statusCode)."
            }
            return "LM Studio request failed with HTTP \(statusCode): \(body)"
        case .invalidPayload:
            return "LM Studio returned an invalid payload."
        case .missingFinalResponse:
            return "LM Studio stream ended without a final response."
        }
    }
}

final class LMStudioAPIClient: @unchecked Sendable {
    private let session: URLSession

    init(timeoutInterval: TimeInterval = 60 * 60 * 24) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    func fetchModels(baseURLText: String, apiToken: String?) async throws -> [LMStudioModelSummary] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded: LMStudioModelListResponse = try await performJSONRequest(
            baseURLText: baseURLText,
            apiToken: apiToken,
            path: "models",
            method: "GET",
            body: nil,
            acceptsEventStream: false,
            decoder: decoder
        )
        return decoded.models
    }

    func streamChat(
        baseURLText: String,
        apiToken: String?,
        requestBody: LMStudioChatRequestBody,
        debugHandler: @escaping @Sendable (String) async -> Void,
        eventHandler: @escaping @Sendable (LMStudioEventRecord) async -> Void
    ) async throws -> LMStudioChatFinalResult {
        let url = try normalizedURL(baseURLText, path: "chat")
        let body = try JSONEncoder().encode(requestBody)
        let request = try makeRequest(url: url, method: "POST", apiToken: apiToken, body: body, acceptsEventStream: true)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LMStudioClientError.invalidResponse
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let errorBody = await collectBodyText(from: bytes)
            throw LMStudioClientError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        var currentEventName: String?
        var currentDataLines: [String] = []
        var finalResult: LMStudioChatFinalResult?

        func flushCurrentEvent() async throws {
            defer {
                currentEventName = nil
                currentDataLines.removeAll(keepingCapacity: true)
            }

            let payloadText = currentDataLines.joined(separator: "\n")
            let payload = Self.jsonObject(from: payloadText) ?? [:]
            let eventName = currentEventName ?? (payload["type"] as? String)
            await debugHandler(eventName ?? "<missing>")
            guard let record = Self.record(eventName: eventName, payload: payload) else {
                return
            }

            await eventHandler(record)

            if record.type == "chat.end" {
                finalResult = Self.finalResult(payload: payload)
            }
        }

        for try await line in bytes.lines {
            if Task.isCancelled {
                throw CancellationError()
            }

            if line.isEmpty {
                try await flushCurrentEvent()
                continue
            }

            if line.hasPrefix(":") {
                await debugHandler("comment: \(line.prefix(200))")
                continue
            }

            if line.hasPrefix("event:") {
                currentEventName = Self.sseValue(from: line, prefix: "event:")
                await debugHandler("event: \(currentEventName ?? "")")
                continue
            }

            if line.hasPrefix("data:") {
                let dataValue = Self.sseValue(from: line, prefix: "data:")
                await debugHandler("data: \(dataValue.prefix(200))")

                // If this data line already contains a JSON object, emit it immediately.
                if let payload = Self.jsonObject(from: dataValue),
                   let eventName = currentEventName ?? (payload["type"] as? String),
                   let record = Self.record(eventName: eventName, payload: payload)
                {
                    await eventHandler(record)
                    if record.type == "chat.end" {
                        finalResult = Self.finalResult(payload: payload)
                    }
                    continue
                }

                currentDataLines.append(dataValue)
                continue
            }

            await debugHandler("unhandled_line: \(line.prefix(200))")
        }

        if currentEventName != nil || !currentDataLines.isEmpty {
            try await flushCurrentEvent()
        }

        guard let finalResult else {
            throw LMStudioClientError.missingFinalResponse
        }

        return finalResult
    }

    private func makeRequest(
        url: URL,
        method: String,
        apiToken: String?,
        body: Data?,
        acceptsEventStream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if acceptsEventStream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        if let apiToken, !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    private func performJSONRequest<ResponseBody: Decodable>(
        baseURLText: String,
        apiToken: String?,
        path: String,
        method: String,
        body: Data?,
        acceptsEventStream: Bool,
        decoder: JSONDecoder
    ) async throws -> ResponseBody {
        let url = try normalizedURL(baseURLText, path: path)
        let request = try makeRequest(
            url: url,
            method: method,
            apiToken: apiToken,
            body: body,
            acceptsEventStream: acceptsEventStream
        )
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response: response, body: data)
        return try decoder.decode(ResponseBody.self, from: data)
    }

    private func normalizedURL(_ baseURLText: String, path: String) throws -> URL {
        let trimmed = baseURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            throw LMStudioClientError.invalidBaseURL(baseURLText)
        }

        if components.path.isEmpty || components.path == "/" {
            components.path = "/api/v1/\(path)"
        } else if components.path.hasSuffix("/api/v1") {
            components.path = "\(components.path)/\(path)"
        } else if components.path.hasSuffix("/api/v1/") {
            components.path = "\(components.path)\(path)"
        } else {
            let normalizedPath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
            if normalizedPath.hasSuffix("/api/v1") {
                components.path = "\(normalizedPath)/\(path)"
            } else {
                components.path = "\(normalizedPath)/api/v1/\(path)"
            }
        }

        guard let url = components.url else {
            throw LMStudioClientError.invalidBaseURL(baseURLText)
        }
        return url
    }

    private func validateHTTPResponse(response: URLResponse, body: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LMStudioClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: body, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw LMStudioClientError.httpError(statusCode: httpResponse.statusCode, body: bodyText)
        }
    }

    private func collectBodyText(from bytes: URLSession.AsyncBytes) async -> String {
        var chunks: [String] = []

        do {
            for try await line in bytes.lines {
                chunks.append(line)
            }
        } catch {
            return ""
        }

        return chunks.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sseValue(from line: String, prefix: String) -> String {
        var value = String(line.dropFirst(prefix.count))
        if value.hasPrefix(" ") {
            value.removeFirst()
        }
        return value
    }

    private static func jsonObject(from text: String) -> [String: Any]? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [:]
        }

        guard let data = text.data(using: .utf8) else {
            return nil
        }

        let object = try? JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: Any]
    }

    private static func finalResult(payload: [String: Any]) -> LMStudioChatFinalResult? {
        let resultObject = (payload["result"] as? [String: Any]) ?? payload
        let modelInstanceID = resultObject["model_instance_id"] as? String
        let responseID = resultObject["response_id"] as? String
        let outputItems = resultObject["output"] as? [[String: Any]]
        let finalText = messageText(from: outputItems)
        return LMStudioChatFinalResult(
            modelInstanceID: modelInstanceID,
            responseID: responseID,
            finalText: finalText,
            rawOutputItems: outputItems
        )
    }

    private static func messageText(from items: [[String: Any]]?) -> String {
        guard let items else { return "" }
        let fragments = items.compactMap { item -> String? in
            guard let type = item["type"] as? String else { return nil }
            switch type {
            case "message":
                return item["content"] as? String
            default:
                return nil
            }
        }
        return fragments.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func record(eventName: String?, payload: [String: Any]) -> LMStudioEventRecord? {
        guard let eventName else { return nil }

        let timestamp = Date()
        switch eventName {
        case "chat.start":
            let modelInstanceID = payload["model_instance_id"] as? String
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Chat started",
                detail: modelInstanceID,
                severity: .neutral
            )

        case "model_load.start":
            let modelInstanceID = payload["model_instance_id"] as? String
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Loading model",
                detail: modelInstanceID,
                severity: .progress
            )

        case "model_load.progress":
            let progress = payload["progress"] as? Double
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Model loading",
                detail: progress.map { "\(Int($0 * 100))%" },
                severity: .progress,
                progress: progress
            )

        case "model_load.end":
            let loadTime = payload["load_time_seconds"] as? Double
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Model loaded",
                detail: loadTime.map { String(format: "%.2fs", $0) },
                severity: .success
            )

        case "prompt_processing.start":
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Processing prompt",
                severity: .neutral
            )

        case "prompt_processing.progress":
            let progress = payload["progress"] as? Double
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Prompt processing",
                detail: progress.map { "\(Int($0 * 100))%" },
                severity: .progress,
                progress: progress
            )

        case "prompt_processing.end":
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Prompt processed",
                severity: .success
            )

        case "reasoning.start":
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Reasoning",
                severity: .neutral
            )

        case "reasoning.end":
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Reasoning ended",
                severity: .neutral
            )

        case "reasoning.delta":
            let fragment = payload["content"] as? String
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Reasoning delta",
                detail: fragment,
                severity: .neutral
            )

        case "tool_call.start":
            let tool = payload["tool"] as? String ?? "tool"
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: tool,
                toolName: tool,
                severity: .tool
            )

        case "tool_call.arguments":
            let tool = payload["tool"] as? String ?? "tool"
            let arguments = payload["arguments"] ?? [:]
            let detail = Self.prettyPrintedJSONString(from: arguments) ?? Self.describeJSONValue(arguments)
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: tool,
                detail: detail,
                toolName: tool,
                severity: .tool
            )

        case "tool_call.success":
            let tool = payload["tool"] as? String ?? "tool"
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: tool,
                detail: "success",
                toolName: tool,
                severity: .success
            )

        case "tool_call.failure":
            let tool = payload["tool"] as? String ?? "tool"
            let detail = payload["error"] as? String
                ?? Self.prettyPrintedJSONString(from: payload["output"]) 
                ?? Self.describeJSONValue(payload["output"])
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: tool,
                detail: detail,
                toolName: tool,
                severity: .error
            )

        case "message.start":
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Message",
                severity: .neutral
            )

        case "message.end":
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Message ended",
                severity: .success
            )

        case "message.delta":
            let fragment = payload["content"] as? String
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Message delta",
                detail: fragment,
                severity: .neutral
            )

        case "error":
            let error = payload["error"] as? [String: Any]
            let message = error?["message"] as? String ?? Self.describeJSONValue(error)
            let errorType = error?["type"] as? String
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Error",
                detail: [errorType, message].compactMap { $0 }.joined(separator: " • "),
                severity: .error
            )

        case "chat.end":
            let responseID = ((payload["result"] as? [String: Any]) ?? payload)["response_id"] as? String
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: "Chat completed",
                detail: responseID,
                severity: .success
            )

        default:
            return LMStudioEventRecord(
                timestamp: timestamp,
                type: eventName,
                title: eventName.replacingOccurrences(of: "_", with: " ").capitalized,
                detail: Self.describeJSONValue(payload),
                severity: .neutral
            )
        }
    }

    private static func describeJSONValue(_ value: Any?) -> String? {
        guard let value else { return nil }

        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let array = value as? [Any] {
            return array.compactMap { describeJSONValue($0) }.joined(separator: ", ")
        }
        if let object = value as? [String: Any] {
            let pieces = object.compactMap { key, value -> String? in
                guard let text = describeJSONValue(value) else { return nil }
                return "\(key)=\(text)"
            }
            return pieces.joined(separator: ", ")
        }
        return String(describing: value)
    }

    private static func prettyPrintedJSONString(from value: Any?) -> String? {
        guard let value else { return nil }
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
