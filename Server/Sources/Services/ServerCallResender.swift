import Foundation

@MainActor
extension AppModel {
    func resendServerCall(_ entry: MCPServerCallEntry) async {
        guard let url = URL(string: "http://\(mcpServerAddress)\(entry.requestPath)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = entry.requestMethod
        request.httpBody = entry.requestBody
        request.timeoutInterval = 15

        for (key, value) in entry.requestHeaders {
            let lower = key.lowercased()
            if lower == "host" || lower == "content-length" || lower == "connection" {
                continue
            }
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            appendLog("Resend failed: \(error.localizedDescription)", level: .warning)
        }
    }
}

