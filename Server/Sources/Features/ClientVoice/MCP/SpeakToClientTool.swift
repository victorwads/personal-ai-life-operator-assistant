import Foundation

struct SpeakToClientTool: MCPToolDefinition {
    private let repository: ClientInteractionRequestRepository
    private let sharedLocks: SharedLockRegistry
    private let source: ClientInteractionRequest.Source

    init(
        repository: ClientInteractionRequestRepository,
        sharedLocks: SharedLockRegistry,
        source: ClientInteractionRequest.Source = .desktop
    ) {
        self.repository = repository
        self.sharedLocks = sharedLocks
        self.source = source
    }

    let name = "speak_to_client"
    let icon = "speaker.wave.2"
    let description = "Registers an auditable message for the client."
    let group = "clientVoice"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "text": .object(["type": .string("string")])
        ]),
        "required": .array([.string("issueId"), .string("text")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "text", value: .string("Please let the client know the migration is ready."))
    ]
    let traits: [MCPToolTrait] = [.sideEffect]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let issueId = try MCPSupport.string("issueId", from: call)
        let text = try MCPSupport.string("text", from: call)

        let request = try await repository.createRequest(
            issueId: issueId,
            kind: .speak,
            status: .initialized,
            promptText: text,
            responseText: nil,
            source: source
        )

        guard let requestID = request.id, !requestID.isEmpty else {
            return .string("error: speak_to_client created a request without an id, so delivery cannot be awaited.")
        }

        let isClientPresent = true
        // TODO: Read real client presence from the proper runtime/service state.

        guard isClientPresent else {
            return .string("warning: client is not present. The message was registered and will be delivered when the client is available. You may continue.")
        }

        try await sharedLocks.lockAndWait(id: "speak_to_client:\(requestID)")

        return .string("ok: message delivered to the client.")
    }
}
