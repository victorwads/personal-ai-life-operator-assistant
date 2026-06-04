import Foundation

struct AskToClientTool: MCPToolDefinition {
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

    let name = "ask_to_client"
    let icon = "questionmark.bubble"
    let description = "Registers a manual question for the client to answer later."
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
        .init(name: "text", value: .string("Can the client confirm the preferred delivery window?"))
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
            kind: .ask,
            status: .initialized,
            promptText: text,
        )

        guard let requestID = request.id, !requestID.isEmpty else {
            return .string("error: ask_to_client created a request without an id, so the response cannot be awaited.")
        }

        let isClientPresent = await MainActor.run { isClientPresentProvider() }

        guard isClientPresent else {
            return .string("pending: question registered for the client. The client will answer when available. Continue autonomously if possible or wait for an event. You will be notified when the client responds.")
        }

        let lockID = "ask_to_client:\(requestID)"
        try await sharedLocks.lockAndWait(id: lockID)

        let updatedRequest = try await repository.getRequest(id: requestID)
        let responseText = updatedRequest.responseText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !responseText.isEmpty else {
            return .string("pending: question registered for the client. The client could not answer now. Continue autonomously if possible or wait for an event. You will be notified when the client responds.")
        }

        _ = try await repository.markCompleted(id: requestID)

        return .string(responseText)
    }
}
