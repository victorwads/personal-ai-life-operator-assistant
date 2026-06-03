import AppKit
import Foundation

struct AIConnectionErrorLogStore {
    private let fileManager: FileManager
    private let logsDirectoryURL: URL
    private let openFolderHandler: @Sendable (URL) -> Void

    init(
        fileManager: FileManager = .default,
        logsDirectoryURL: URL? = nil,
        openFolderHandler: @escaping @Sendable (URL) -> Void = { url in
            NSWorkspace.shared.open(url)
        }
    ) {
        self.fileManager = fileManager
        self.logsDirectoryURL = logsDirectoryURL ?? Self.defaultLogsDirectoryURL(fileManager: fileManager)
        self.openFolderHandler = openFolderHandler
    }

    func ensureLogsDirectoryExists() throws {
        try fileManager.createDirectory(
            at: logsDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func writeFailureLog(_ payload: FailureLogPayload) throws -> URL {
        try ensureLogsDirectoryExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let fileName = payload.fileName
        let fileURL = logsDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func openLogsFolder() throws {
        try ensureLogsDirectoryExists()
        openFolderHandler(logsDirectoryURL)
    }

    func logsFolderPath() -> String {
        logsDirectoryURL.path
    }

    private static func defaultLogsDirectoryURL(fileManager: FileManager) -> URL {
        let applicationsURL = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)

        return applicationsURL.appendingPathComponent("AIAssistantHub Error Logs", isDirectory: true)
    }
}

extension AIConnectionErrorLogStore {
    struct FailureLogPayload: Encodable {
        let recordedAt: Date
        let runId: String?
        let cycleNumber: Int
        let message: String
        let status: String
        let userPrompt: String
        let assistantText: String
        let reasoningText: String
        let accumulatedErrors: [String]
        let providerFailure: ProviderFailurePayload?
        let toolCalls: [ToolCallPayload]
        let debugEvents: [DebugEventPayload]

        var fileName: String {
            "ai-connection-cycle-\(cycleNumber)-\(Self.timestampFormatter.string(from: recordedAt)).json"
        }

        private static let timestampFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
            return formatter
        }()
    }

    struct ToolCallPayload: Encodable {
        let id: String
        let name: String
        let status: String
        let argumentsJSON: String
        let responseText: String?
        let errorText: String?
        let startedAt: Date
        let endedAt: Date?
    }

    struct ProviderFailurePayload: Encodable {
        let message: String
        let provider: String?
        let model: String?
        let endpoint: String?
        let statusCode: Int?
        let responseHeaders: [String: String]
        let responseBody: String?
        let requestBody: String?
        let requestMessageCount: Int?
        let requestToolCount: Int?
        let underlyingError: String?
    }

    struct DebugEventPayload: Encodable {
        let kind: String
        let summary: String
        let timestamp: Date
    }

    struct ProviderExchangeLogPayload: Encodable {
        let recordedAt: Date
        let provider: String?
        let model: String?
        let endpoint: String?
        let statusCode: Int?
        let requestBody: String?
        let responseBody: String?
        let responseHeaders: [String: String]
        let outcome: String
        let underlyingError: String?

        var fileName: String {
            "ai-provider-exchange-\(Self.timestampFormatter.string(from: recordedAt)).json"
        }

        private static let timestampFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"
            return formatter
        }()
    }
}

extension AIConnectionErrorLogStore {
    func writeProviderExchangeLog(_ payload: ProviderExchangeLogPayload) throws -> URL {
        try ensureLogsDirectoryExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let fileURL = logsDirectoryURL.appendingPathComponent(payload.fileName, isDirectory: false)
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
