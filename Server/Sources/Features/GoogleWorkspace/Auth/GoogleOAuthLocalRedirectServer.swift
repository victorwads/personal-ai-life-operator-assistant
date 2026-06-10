import Foundation
import Network
import AppKit

@MainActor
final class GoogleOAuthLocalRedirectServer {
    private static let responseHTML = """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>Google Workspace Authentication</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #f5f5f7;
            color: #1d1d1f;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
          }
          .card {
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 400px;
          }
          h1 { color: #34a853; margin-top: 0; }
          p { color: #86868b; margin-bottom: 24px; }
          .btn {
            background-color: #0071e3;
            color: white;
            padding: 10px 20px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 500;
          }
        </style>
        <script>
          document.addEventListener("DOMContentLoaded", function () {
            setTimeout(function () {
              window.close();
            }, 3000);
          });
        </script>
      </head>
      <body>
        <div class="card">
          <h1>Authentication Success!</h1>
          <p>You have successfully authenticated with Google Workspace. This window will close automatically shortly.</p>
        </div>
      </body>
    </html>
    """

    private static let errorHTML = """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>Google Workspace Authentication Failed</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #f5f5f7;
            color: #1d1d1f;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
          }
          .card {
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 400px;
          }
          h1 { color: #ea4335; margin-top: 0; }
          p { color: #86868b; }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>Authentication Failed</h1>
          <p>Failed to complete the OAuth callback process. Please try again or check the logs.</p>
        </div>
      </body>
    </html>
    """

    func startAndAwaitCode(port: Int, expectedState: String) async throws -> String {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host("127.0.0.1"), port: NWEndpoint.Port(rawValue: UInt16(port))!)

        let listener = try NWListener(using: parameters)
        let state = ServerState(listener: listener)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            state.setContinuation(continuation)

            listener.stateUpdateHandler = { listenerState in
                switch listenerState {
                case .ready:
                    break
                case .failed(let error):
                    state.finish(.failure(error))
                default:
                    break
                }
            }

            listener.newConnectionHandler = { connection in
                state.addConnection(connection)
                Self.handleConnection(
                    connection,
                    expectedState: expectedState,
                    onSuccess: { code in
                        state.finish(.success(code))
                    },
                    onFailure: { error in
                        state.finish(.failure(error))
                    },
                    onIgnore: {
                        state.removeConnection(connection)
                    }
                )
            }

            listener.start(queue: .global(qos: .userInitiated))
            state.scheduleTimeout(seconds: 120) // 2 minutes timeout
        }
    }

    nonisolated private static func handleConnection(
        _ connection: NWConnection,
        expectedState: String,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping (Error) -> Void,
        onIgnore: @escaping () -> Void
    ) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveRequest(
            connection: connection,
            data: Data(),
            expectedState: expectedState,
            onSuccess: onSuccess,
            onFailure: onFailure,
            onIgnore: onIgnore
        )
    }

    nonisolated private static func receiveRequest(
        connection: NWConnection,
        data: Data,
        expectedState: String,
        onSuccess: @escaping (String) -> Void,
        onFailure: @escaping (Error) -> Void,
        onIgnore: @escaping () -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { chunk, _, isComplete, error in
            if let error {
                connection.cancel()
                onFailure(error)
                return
            }

            var buffer = data
            if let chunk {
                buffer.append(chunk)
            }

            if let range = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buffer[..<range.lowerBound]
                guard let headerText = String(data: headerData, encoding: .utf8) else {
                    respond(connection: connection, status: "400 Bad Request", body: "Bad request")
                    onIgnore()
                    return
                }

                let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
                guard let requestLine = lines.first else {
                    respond(connection: connection, status: "400 Bad Request", body: "Bad request")
                    onIgnore()
                    return
                }

                let requestParts = requestLine.split(separator: " ")
                guard requestParts.count >= 2 else {
                    respond(connection: connection, status: "400 Bad Request", body: "Bad request")
                    onIgnore()
                    return
                }

                let path = String(requestParts[1])
                
                // Allow browsers requesting favicon to be ignored without failing the OAuth flow
                if path.hasPrefix("/favicon") {
                    respond(connection: connection, status: "404 Not Found", body: "Not found")
                    onIgnore()
                    return
                }

                guard let urlComponents = URLComponents(string: "http://127.0.0.1" + path),
                      urlComponents.path == "/oauth/google/callback" else {
                    respond(connection: connection, status: "404 Not Found", body: "Not found")
                    onIgnore()
                    return
                }

                let queryItems = urlComponents.queryItems ?? []
                let stateParam = queryItems.first(where: { $0.name == "state" })?.value
                let codeParam = queryItems.first(where: { $0.name == "code" })?.value
                let errorParam = queryItems.first(where: { $0.name == "error" })?.value

                if let errorParam {
                    respond(connection: connection, status: "200 OK", body: Self.errorHTML)
                    onFailure(NSError(domain: "GoogleOAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Google OAuth error: \(errorParam)"]))
                    return
                }

                guard stateParam == expectedState else {
                    respond(connection: connection, status: "400 Bad Request", body: "State mismatch error.")
                    onFailure(NSError(domain: "GoogleOAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "State mismatch. Expected \(expectedState), got \(stateParam ?? "nil")"]))
                    return
                }

                guard let code = codeParam, !code.isEmpty else {
                    respond(connection: connection, status: "400 Bad Request", body: "Missing authorization code.")
                    onFailure(NSError(domain: "GoogleOAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing code query parameter."]))
                    return
                }

                onSuccess(code)
                respond(connection: connection, status: "200 OK", body: Self.responseHTML)
                return
            }

            if isComplete || buffer.count > 32_768 {
                connection.cancel()
                onIgnore()
                return
            }

            receiveRequest(
                connection: connection,
                data: buffer,
                expectedState: expectedState,
                onSuccess: onSuccess,
                onFailure: onFailure,
                onIgnore: onIgnore
            )
        }
    }

    nonisolated private static func respond(connection: NWConnection, status: String, body: String) {
        let bodyData = Data(body.utf8)
        var response = "HTTP/1.1 \(status)\r\n"
        response += "Content-Type: text/html; charset=utf-8\r\n"
        response += "Content-Length: \(bodyData.count)\r\n"
        response += "Connection: close\r\n\r\n"

        var output = Data(response.utf8)
        output.append(bodyData)

        connection.send(content: output, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private final class ServerState: @unchecked Sendable {
    private let lock = NSLock()
    private let listener: NWListener
    private var continuation: CheckedContinuation<String, Error>?
    private var finished = false
    private var timeoutTask: Task<Void, Never>?
    private var connections: [NWConnection] = []

    init(listener: NWListener) {
        self.listener = listener
    }

    func setContinuation(_ continuation: CheckedContinuation<String, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func addConnection(_ connection: NWConnection) {
        lock.lock()
        if !finished {
            connections.append(connection)
        } else {
            connection.cancel()
        }
        lock.unlock()
    }

    func removeConnection(_ connection: NWConnection) {
        lock.lock()
        connections.removeAll { $0 === connection }
        lock.unlock()
    }

    func scheduleTimeout(seconds: TimeInterval) {
        timeoutTask = Task { [weak self] in
            let nanos = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            self?.finish(.failure(NSError(domain: "GoogleOAuth", code: 4, userInfo: [NSLocalizedDescriptionKey: "Authentication flow timed out."])))
        }
    }

    func finish(_ result: Result<String, Error>) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        let timeoutTask = self.timeoutTask
        self.timeoutTask = nil
        let connections = self.connections
        self.connections = []
        lock.unlock()

        switch result {
        case .success(let code):
            continuation?.resume(returning: code)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }

        Task.detached {
            timeoutTask?.cancel()
            connections.forEach { $0.cancel() }
            self.listener.cancel()
        }
    }
}
