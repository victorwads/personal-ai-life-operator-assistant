import Foundation

enum ClientInteractionRequestRepositoryError: Error {
    case requestNotFound(String)
}

protocol ClientInteractionRequestRepository: AnyObject {
    func listRequests() async throws -> [ClientInteractionRequest]
    func observeRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken
    func getRequest(id: String) async throws -> ClientInteractionRequest
    func createRequest(
        issueId: String?,
        kind: ClientInteractionRequest.Kind,
        status: ClientInteractionRequest.Status,
        promptText: String
    ) async throws -> ClientInteractionRequest
    func markWaitingAgent(
        id: String,
        responseText: String,
    ) async throws -> ClientInteractionRequest
    func markSpeaking(
        id: String,
    ) async throws -> ClientInteractionRequest
    func markWaitingUser(
        id: String,
    ) async throws -> ClientInteractionRequest
    func markCompleted(
        id: String,
    ) async throws -> ClientInteractionRequest
    func markCancelled(id: String) async throws -> ClientInteractionRequest
}

final class FirestoreClientInteractionRequestRepository: FirestoreRepository<ClientInteractionRequest>, ClientInteractionRequestRepository {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "ClientInteractionRequest",
            path: .profileScoped(scope: scope, collection: "ClientInteractionRequests")
        )
    }

    func listRequests() async throws -> [ClientInteractionRequest] {
        try await query(
            sortedBy: [FirestoreRepositorySort(field: "_createdAt", descending: true)]
        )
    }

    func listRequests(issueId: String) async throws -> [ClientInteractionRequest] {
        try await listRequests().filter { $0.issueId == issueId }
    }

    func observeRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken {
        super.observe(listener)
    }

    func getRequest(id: String) async throws -> ClientInteractionRequest {
        try await existingRequest(id: id)
    }

    func createRequest(
        issueId: String?,
        kind: ClientInteractionRequest.Kind,
        status: ClientInteractionRequest.Status,
        promptText: String,
    ) async throws -> ClientInteractionRequest {
        let request = ClientInteractionRequest(
            issueId: issueId,
            kind: kind,
            status: status,
            promptText: promptText,
        )
        return try await super.save(request, merge: true)
    }

    func markWaitingAgent(
        id: String,
        responseText: String,
    ) async throws -> ClientInteractionRequest {
        try await super.update(
            id: id,
            data: makeUpdateData(
                status: .waitingAgent,
                responseText: responseText,
            )
        )
        return try await existingRequest(id: id)
    }

    func markWaitingUser(
        id: String,
    ) async throws -> ClientInteractionRequest {
        try await super.update(
            id: id,
            data: makeUpdateData(status: .waitingUser)
        )
        return try await existingRequest(id: id)
    }

    func markSpeaking(
        id: String,
    ) async throws -> ClientInteractionRequest {
        try await super.update(
            id: id,
            data: makeUpdateData(status: .speaking)
        )
        return try await existingRequest(id: id)
    }

    func markCompleted(
        id: String,
    ) async throws -> ClientInteractionRequest {
        try await super.update(
            id: id,
            data: makeUpdateData(status: .completed)
        )
        return try await existingRequest(id: id)
    }

    func markCancelled(id: String) async throws -> ClientInteractionRequest {
        try await super.update(
            id: id,
            data: makeUpdateData(status: .cancelled)
        )
        return try await existingRequest(id: id)
    }

    private func existingRequest(id: String) async throws -> ClientInteractionRequest {
        guard let request = try await getById(id) else {
            throw ClientInteractionRequestRepositoryError.requestNotFound(id)
        }

        return request
    }

    private func makeUpdateData(
        status: ClientInteractionRequest.Status,
        responseText _: String? = nil,
    ) -> [String: Any] {
        return [
            "status": status.rawValue,
            "device": ClientInteractionRequest.Device.desktop.rawValue
        ]
    }

    private func makeUpdateData(
        status: ClientInteractionRequest.Status,
        responseText: String,
    ) -> [String: Any] {
        var data = makeUpdateData(status: status)
        data["responseText"] = responseText
        return data
    }
}
