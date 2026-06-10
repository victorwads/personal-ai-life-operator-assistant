import Foundation

final class FirestoreAssistantContactRepository: FirestoreRepository<AssistantContact> {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "AssistantContact",
            path: .profileScoped(scope: scope, collection: "AssistantContacts")
        )
    }

    func findByGooglePersonId(_ googlePersonId: String) async throws -> AssistantContact? {
        try await query(
            matching: ["googlePersonId": googlePersonId],
            limit: 1
        ).first
    }

    func findByWhatsappChatId(_ whatsappChatId: String) async throws -> AssistantContact? {
        try await query(
            matching: ["whatsappChatId": whatsappChatId],
            limit: 1
        ).first
    }
}
