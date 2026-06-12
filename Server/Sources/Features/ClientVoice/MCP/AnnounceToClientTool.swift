import Foundation

struct AnnounceToClientTool: MCPToolDefinition {
    private static let questionHint = "warning: this message contains a question mark; prefer ask_to_client(...) when you need a client answer. The client will not be able to answer you with announce_to_client(...)."
    private let repository: ClientInteractionRequestRepository
    private let sharedLocks: SharedLockRegistry
    private let isClientPresentProvider: @MainActor @Sendable () -> Bool

    init(
        repository: ClientInteractionRequestRepository,
        sharedLocks: SharedLockRegistry,
        isClientPresentProvider: @escaping @MainActor @Sendable () -> Bool,
    ) {
        self.repository = repository
        self.sharedLocks = sharedLocks
        self.isClientPresentProvider = isClientPresentProvider
    }

    let name = "announce_to_client"
    let icon = "speaker.wave.2"
    let description = "Registers an auditable message for the client. Use ask_to_client for question-like text."
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
        let containsQuestionMark = text.contains("?")

        let request = try await repository.createRequest(
            issueId: issueId,
            kind: .speak,
            status: .initialized,
            promptText: text,
        )

        guard let requestID = request.id, !requestID.isEmpty else {
            return .string("error: announce_to_client created a request without an id, so delivery cannot be awaited.")
        }

        let isClientPresent = await MainActor.run { isClientPresentProvider() }

        guard isClientPresent else {
            if containsQuestionMark {
                return .string("\(Self.questionHint) The message was registered and will be delivered when the client is available. You may continue.")
            }
            return .string("warning: client is not present. The message was registered and will be delivered when the client is available. You may continue.")
        }

        try await sharedLocks.lockAndWait(id: "announce_to_client:\(requestID)")

        if containsQuestionMark {
            return .string("\(Self.questionHint) The message was delivered to the client. You may continue.")
        }

        return .string("ok: message delivered to the client.")
    }
}
