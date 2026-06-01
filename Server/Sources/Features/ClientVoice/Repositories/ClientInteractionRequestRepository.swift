import Foundation

enum ClientInteractionRequestRepositoryError: Error {
    case requestNotFound(String)
}

protocol ClientInteractionRequestRepository: AnyObject {
    func listRequests() async throws -> [ClientInteractionRequest]
    func listPendingRequests() async throws -> [ClientInteractionRequest]
    func observeRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken
    func observePendingRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken
    func createRequest(
        issueId: String,
        kind: ClientInteractionKind,
        promptText: String,
        clientPresenceAtCreation: ClientPresenceState,
        source: ClientInteractionSource,
        targetDeviceId: String?,
        metadata: [String: String]
    ) async throws -> ClientInteractionRequest
    func updateRequest(_ request: ClientInteractionRequest) async throws -> ClientInteractionRequest
    func markDelivered(id: String) async throws -> ClientInteractionRequest
    func markCompleted(id: String, responseText: String?) async throws -> ClientInteractionRequest
    func markCancelled(id: String) async throws -> ClientInteractionRequest
    func markFailed(id: String, errorMessage: String) async throws -> ClientInteractionRequest
    func deleteRequest(id: String) async throws
}

final class FirestoreClientInteractionRequestRepository: FirestoreRepository<ClientInteractionRequest>, ClientInteractionRequestRepository {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "ClientInteractionRequest",
            path: .profileScoped(scope: scope, collection: "ClientInteractionRequests")
        )
    }

    func listRequests() async throws -> [ClientInteractionRequest] {
        let requests = try await query(
            sortedBy: [FirestoreRepositorySort(field: "requestedAt", descending: true)]
        )
        return Self.sortRequests(requests)
    }

    func listPendingRequests() async throws -> [ClientInteractionRequest] {
        try await listRequests().filter { $0.status == .pending }
    }

    func listRequests(issueId: String) async throws -> [ClientInteractionRequest] {
        try await listRequests().filter { $0.issueId == issueId }
    }

    func observeRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken {
        super.observe { requests in
            listener(Self.sortRequests(requests))
        }
    }

    func observePendingRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken {
        observeRequests { requests in
            listener(requests.filter { $0.status == .pending })
        }
    }

    func createRequest(
        issueId: String,
        kind: ClientInteractionKind,
        promptText: String,
        clientPresenceAtCreation: ClientPresenceState = .unknown,
        source: ClientInteractionSource = .unknown,
        targetDeviceId: String? = nil,
        metadata: [String: String] = [:]
    ) async throws -> ClientInteractionRequest {
        let now = Date()
        let request = ClientInteractionRequest(
            issueId: issueId,
            kind: kind,
            status: .pending,
            clientPresenceAtCreation: clientPresenceAtCreation,
            promptText: promptText,
            requestedAt: now,
            lastStatusChangeAt: now,
            source: source,
            targetDeviceId: targetDeviceId,
            metadata: metadata
        )
        return try await super.save(request, merge: true)
    }

    func updateRequest(_ request: ClientInteractionRequest) async throws -> ClientInteractionRequest {
        var updated = request
        updated.lastStatusChangeAt = Date()
        return try await super.save(updated, merge: true)
    }

    func markDelivered(id: String) async throws -> ClientInteractionRequest {
        var request = try await existingRequest(id: id)
        let now = Date()
        request.status = .delivered
        request.deliveredAt = now
        request.lastStatusChangeAt = now
        return try await super.save(request, merge: true)
    }

    func markCompleted(id: String, responseText: String? = nil) async throws -> ClientInteractionRequest {
        var request = try await existingRequest(id: id)
        let now = Date()
        request.status = .completed
        request.responseText = responseText
        request.completedAt = now
        request.lastStatusChangeAt = now
        return try await super.save(request, merge: true)
    }

    func markCancelled(id: String) async throws -> ClientInteractionRequest {
        var request = try await existingRequest(id: id)
        let now = Date()
        request.status = .cancelled
        request.cancelledAt = now
        request.lastStatusChangeAt = now
        return try await super.save(request, merge: true)
    }

    func markFailed(id: String, errorMessage: String) async throws -> ClientInteractionRequest {
        var request = try await existingRequest(id: id)
        let now = Date()
        request.status = .failed
        request.failedAt = now
        request.errorMessage = errorMessage
        request.lastStatusChangeAt = now
        return try await super.save(request, merge: true)
    }

    func deleteRequest(id: String) async throws {
        try await delete(id)
    }

    private func existingRequest(id: String) async throws -> ClientInteractionRequest {
        guard let request = try await getById(id) else {
            throw ClientInteractionRequestRepositoryError.requestNotFound(id)
        }

        return request
    }

    private static func sortRequests(_ requests: [ClientInteractionRequest]) -> [ClientInteractionRequest] {
        requests.sorted { lhs, rhs in
            let leftPending = lhs.status == .pending
            let rightPending = rhs.status == .pending

            switch (leftPending, rightPending) {
            case (true, false):
                return true
            case (false, true):
                return false
            case (true, true):
                return pendingDate(for: lhs) < pendingDate(for: rhs)
            case (false, false):
                return historyDate(for: lhs) > historyDate(for: rhs)
            }
        }
    }

    private static func pendingDate(for request: ClientInteractionRequest) -> Date {
        request.requestedAt ?? .distantFuture
    }

    private static func historyDate(for request: ClientInteractionRequest) -> Date {
        request.requestedAt ?? .distantPast
    }
}
