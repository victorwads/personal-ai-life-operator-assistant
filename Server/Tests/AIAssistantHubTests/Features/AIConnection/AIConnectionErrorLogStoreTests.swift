import Foundation
import XCTest
@testable import AIAssistantHub

final class AIConnectionErrorLogStoreTests: XCTestCase {
    func testWriteFailureLogCreatesJSONFileInConfiguredDirectory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = AIConnectionErrorLogStore(
            logsDirectoryURL: directoryURL,
            openFolderHandler: { _ in }
        )
        let payload = AIConnectionErrorLogStore.FailureLogPayload(
            recordedAt: Date(timeIntervalSince1970: 1_717_000_000),
            runId: "run-1",
            cycleNumber: 7,
            message: "provider exploded",
            status: "recovering",
            userPrompt: "",
            assistantText: "partial output",
            reasoningText: "partial reasoning",
            accumulatedErrors: ["provider exploded"],
            providerFailure: AIConnectionErrorLogStore.ProviderFailurePayload(
                message: "AI provider request failed with status code 500.",
                provider: "openRouter",
                model: "model-1",
                endpoint: "https://provider.example/v1/chat/completions",
                statusCode: 500,
                responseHeaders: ["content-type": "application/json"],
                responseBody: "{\"error\":{\"message\":\"boom\"}}",
                requestBody: "{\"model\":\"model-1\"}",
                requestMessageCount: 2,
                requestToolCount: 1,
                underlyingError: "server error"
            ),
            toolCalls: [
                AIConnectionErrorLogStore.ToolCallPayload(
                    id: "tool-1",
                    name: "wait_for_event",
                    status: "failed",
                    argumentsJSON: "{}",
                    responseText: nil,
                    errorText: "provider exploded",
                    startedAt: Date(timeIntervalSince1970: 1_717_000_000),
                    endedAt: Date(timeIntervalSince1970: 1_717_000_005)
                )
            ],
            debugEvents: [
                AIConnectionErrorLogStore.DebugEventPayload(
                    kind: "cycle.failed",
                    summary: "Cycle 7 failed: provider exploded",
                    timestamp: Date(timeIntervalSince1970: 1_717_000_010)
                )
            ]
        )

        let fileURL = try store.writeFailureLog(payload)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("\"cycleNumber\" : 7"))
        XCTAssertTrue(contents.contains("\"message\" : \"provider exploded\""))
        XCTAssertTrue(contents.contains("\"statusCode\" : 500"))
    }

    func testWriteProviderExchangeLogCreatesJSONFileInConfiguredDirectory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = AIConnectionErrorLogStore(
            logsDirectoryURL: directoryURL,
            openFolderHandler: { _ in }
        )
        let payload = AIConnectionErrorLogStore.ProviderExchangeLogPayload(
            recordedAt: Date(timeIntervalSince1970: 1_717_000_111),
            provider: "lmStudio",
            model: "model-1",
            endpoint: "http://localhost:1234/v1/chat/completions",
            statusCode: 500,
            requestBody: "{\"messages\":[]}",
            responseBody: "<html>Internal Server Error</html>",
            responseHeaders: ["content-type": "text/html"],
            outcome: "failed",
            underlyingError: "server error"
        )

        let fileURL = try store.writeProviderExchangeLog(payload)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("\"outcome\" : \"failed\""))
        XCTAssertTrue(contents.contains("\"statusCode\" : 500"))
        XCTAssertTrue(contents.contains("Internal Server Error"))
    }
}
