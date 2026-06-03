import Foundation

enum ClientInteractionRequestRepositoryError: Error {
    case requestNotFound(String)
}

protocol ClientInteractionRequestRepository: AnyObject {
    func listRequests() async throws -> [ClientInteractionRequest]
    func observeRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken
    func getRequest(id: String) async throws -> ClientInteractionRequest
    func createRequest(
        issueId: String,
        kind: ClientInteractionRequest.Kind,
        status: ClientInteractionRequest.Status,
        promptText: String,
        responseText: String?,
        source: ClientInteractionRequest.Source?
    ) async throws -> ClientInteractionRequest
    func markWaitingAgent(
        id: String,
        responseText: String,
        source: ClientInteractionRequest.Source?
    ) async throws -> ClientInteractionRequest
    func markCompleted(
        id: String,
        source: ClientInteractionRequest.Source?
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
        issueId: String,
        kind: ClientInteractionRequest.Kind,
        status: ClientInteractionRequest.Status,
        promptText: String,
        responseText: String? = nil,
        source: ClientInteractionRequest.Source? = nil
    ) async throws -> ClientInteractionRequest {
        let request = ClientInteractionRequest(
            issueId: issueId,
            kind: kind,
            status: status,
            promptText: promptText,
            responseText: responseText,
            source: source
        )
        return try await super.save(request, merge: true)
    }

    func markWaitingAgent(
        id: String,
        responseText: String,
        source: ClientInteractionRequest.Source? = nil
    ) async throws -> ClientInteractionRequest {
        var request = try await existingRequest(id: id)
        request.status = .waitingAgent
        request.responseText = responseText
        request.source = source ?? request.source
        return try await super.save(request, merge: true)
    }

    func markCompleted(
        id: String,
        source: ClientInteractionRequest.Source? = nil
    ) async throws -> ClientInteractionRequest {
        var request = try await existingRequest(id: id)
        request.status = .completed
        request.source = source ?? request.source
        return try await super.save(request, merge: true)
    }

    func markCancelled(id: String) async throws -> ClientInteractionRequest {
        var request = try await existingRequest(id: id)
        request.status = .cancelled
        return try await super.save(request, merge: true)
    }

    private func existingRequest(id: String) async throws -> ClientInteractionRequest {
        guard let request = try await getById(id) else {
            throw ClientInteractionRequestRepositoryError.requestNotFound(id)
        }

        return request
    }
}
