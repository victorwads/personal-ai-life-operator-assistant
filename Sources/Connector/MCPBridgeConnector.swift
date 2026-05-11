import Foundation
import Network

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value.")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }

        return nil
    }

    var intValue: Int? {
        if case .number(let value) = self {
            return Int(value)
        }

        return nil
    }

    static func from(date: Date?) -> JSONValue {
        guard let date else {
            return .null
        }

        return .string(ISO8601DateFormatter().string(from: date))
    }
}

struct MCPToolDefinition {
    let name: String
    let description: String
    let inputSchema: [String: JSONValue]

    var jsonValue: JSONValue {
        .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .object(inputSchema)
        ])
    }
}

struct MCPToolCall {
    let name: String
    let arguments: [String: JSONValue]
}

struct MCPHTTPRequest {
    let id: JSONValue?
    let method: String
    let params: [String: JSONValue]
}

enum MCPBridgeError: LocalizedError {
    case invalidRequest
    case unsupportedMethod(String)
    case missingParameter(String)
    case invalidParameter(String)
    case listenerStartFailed

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid JSON-RPC request."
        case .unsupportedMethod(let method):
            return "Unsupported MCP method: \(method)"
        case .missingParameter(let name):
            return "Missing parameter: \(name)"
        case .invalidParameter(let name):
            return "Invalid parameter: \(name)"
        case .listenerStartFailed:
            return "Failed to start MCP listener."
        }
    }
}

protocol MCPBridgeConnecting: AnyObject {
    var isRunning: Bool { get }
    var boundPort: Int { get }
    func configure(host: String, port: Int)
    func setRequestHandler(_ handler: @escaping @Sendable (MCPHTTPRequest) async -> Result<JSONValue, Error>)
    func start() async throws
    func stop() async
}

final class MCPBridgeConnector: MCPBridgeConnecting {
    private let queue = DispatchQueue(label: "dev.wads.AssistantMCPServer.mcp", qos: .userInitiated)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var listener: NWListener?
    private var handler: (@Sendable (MCPHTTPRequest) async -> Result<JSONValue, Error>)?
    private(set) var isRunning = false
    private(set) var boundPort: Int = 8080
    private var host = "localhost"

    func configure(host: String, port: Int) {
        self.host = host
        self.boundPort = port
    }

    func setRequestHandler(_ handler: @escaping @Sendable (MCPHTTPRequest) async -> Result<JSONValue, Error>) {
        self.handler = handler
    }

    func start() async throws {
        guard listener == nil else {
            return
        }

        guard let port = NWEndpoint.Port(rawValue: UInt16(boundPort)) else {
            throw MCPBridgeError.invalidParameter("port")
        }

        let parameters = NWParameters.tcp
        let listener = try NWListener(using: parameters, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
            case .failed, .cancelled:
                self?.isRunning = false
                self?.listener = nil
            default:
                break
            }
        }

        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() async {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                let payload = self.httpResponse(status: 500, body: self.errorPayload(message: error.localizedDescription))
                self.respond(on: connection, payload: payload)
                return
            }

            var nextBuffer = buffer
            if let content {
                nextBuffer.append(content)
            }

            if let requestData = self.completeHTTPRequestBody(from: nextBuffer) {
                Task {
                    let response = await self.process(body: requestData)
                    self.respond(on: connection, payload: response)
                }
                return
            }

            if isComplete {
                let payload = self.httpResponse(status: 400, body: self.errorPayload(message: MCPBridgeError.invalidRequest.localizedDescription))
                self.respond(on: connection, payload: payload)
                return
            }

            self.receiveRequest(on: connection, buffer: nextBuffer)
        }
    }

    private func process(body: Data) async -> Data {
        do {
            let request = try decodeRequest(from: body)
            guard let handler else {
                return httpResponse(status: 503, body: errorPayload(message: "MCP handler not configured."))
            }

            let result = await handler(request)
            switch result {
            case .success(let value):
                return httpResponse(status: 200, body: successPayload(id: request.id, result: value))
            case .failure(let error):
                return httpResponse(status: 400, body: errorPayload(id: request.id, message: error.localizedDescription))
            }
        } catch {
            return httpResponse(status: 400, body: errorPayload(message: error.localizedDescription))
        }
    }

    private func decodeRequest(from body: Data) throws -> MCPHTTPRequest {
        let rpcRequest = try decoder.decode(JSONRPCRequest.self, from: body)

        switch rpcRequest.method {
        case "tools/list":
            return MCPHTTPRequest(id: rpcRequest.id, method: rpcRequest.method, params: [:])
        case "tools/call":
            guard
                let params = rpcRequest.params,
                case .object(let object) = params,
                let name = object["name"]?.stringValue
            else {
                throw MCPBridgeError.invalidRequest
            }

            let arguments: [String: JSONValue]
            if case .object(let value)? = object["arguments"] {
                arguments = value
            } else {
                arguments = [:]
            }

            return MCPHTTPRequest(
                id: rpcRequest.id,
                method: rpcRequest.method,
                params: [
                    "name": .string(name),
                    "arguments": .object(arguments)
                ]
            )
        default:
            throw MCPBridgeError.unsupportedMethod(rpcRequest.method)
        }
    }

    private func completeHTTPRequestBody(from data: Data) -> Data? {
        guard
            let requestString = String(data: data, encoding: .utf8),
            let headerRange = requestString.range(of: "\r\n\r\n")
        else {
            return nil
        }

        let headers = String(requestString[..<headerRange.lowerBound])
        let bodyStart = requestString.distance(from: requestString.startIndex, to: headerRange.upperBound)
        let contentLength = headers
            .split(separator: "\r\n")
            .first(where: { $0.lowercased().hasPrefix("content-length:") })
            .flatMap { Int($0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "") }
            ?? 0

        guard data.count >= bodyStart + contentLength else {
            return nil
        }

        return data.subdata(in: bodyStart..<(bodyStart + contentLength))
    }

    private func respond(on connection: NWConnection, payload: Data) {
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func successPayload(id: JSONValue?, result: JSONValue) -> Data {
        let payload: JSONValue = .object([
            "jsonrpc": .string("2.0"),
            "id": id ?? .null,
            "result": result
        ])

        return (try? encoder.encode(payload)) ?? Data()
    }

    private func errorPayload(id: JSONValue? = nil, message: String) -> Data {
        let payload: JSONValue = .object([
            "jsonrpc": .string("2.0"),
            "id": id ?? .null,
            "error": .object([
                "message": .string(message)
            ])
        ])

        return (try? encoder.encode(payload)) ?? Data()
    }

    private func httpResponse(status: Int, body: Data) -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 503: statusText = "Service Unavailable"
        default: statusText = "Internal Server Error"
        }

        var response = "HTTP/1.1 \(status) \(statusText)\r\n"
        response += "Host: \(host)\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(body.count)\r\n"
        response += "Connection: close\r\n\r\n"

        return Data(response.utf8) + body
    }
}

private struct JSONRPCRequest: Codable {
    let jsonrpc: String?
    let id: JSONValue?
    let method: String
    let params: JSONValue?
}
