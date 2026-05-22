import Foundation
import FirebaseFirestore
import os

enum WhatsAppWebAccountsRepositoryError: LocalizedError {
    case missingParameter(String)

    var errorDescription: String? {
        switch self {
        case .missingParameter(let name):
            return "Missing parameter: \(name)"
        }
    }
}

actor WhatsAppWebAccountsRepository {
    static let shared = WhatsAppWebAccountsRepository()

    private var entries: [WhatsAppWebAccount] = []
    private var listenerRegistration: ListenerRegistrationWrapper?
    private let logger = Logger(subsystem: "dev.wads.AssistantMCPServer", category: "WhatsAppWebAccountsRepository")

    init() {}

    // MARK: - Real-time listener

    func startListening() {
        guard listenerRegistration == nil else { return }

        let firestore = Firestore.firestore()
        let registration = firestore.collection(FirestoreCollections.profiles).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                self.logger.error("Profiles listener error: \(error.localizedDescription)")
                return
            }

            let updated = snapshot?.documents.compactMap { AppProfile.fromFirestoreData($0.data()) }.map(Self.account(from:)) ?? []
            Task { await self.updateEntries(updated) }
        }

        listenerRegistration = ListenerRegistrationWrapper(registration)
    }

    private func updateEntries(_ newEntries: [WhatsAppWebAccount]) {
        entries = newEntries.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        NotificationCenter.default.post(name: .whatsAppWebAccountsRepositoryDidChange, object: nil)
    }

    // MARK: - Read

    func list() -> [WhatsAppWebAccount] {
        entries
    }

    func loadOrCreateAccounts(for profiles: [AppProfile]) async -> [WhatsAppWebAccount] {
        startListening()

        var loaded: [WhatsAppWebAccount] = []

        do {
            for profile in profiles {
                let account = Self.account(from: profile)
                try await persistProfile(from: account)
                loaded.append(account)
            }

            entries = loaded.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            NotificationCenter.default.post(name: .whatsAppWebAccountsRepositoryDidChange, object: nil)
            return entries
        } catch {
            logger.error("Failed to load WhatsApp accounts from profiles: \(error.localizedDescription)")
            return entries
        }
    }

    // MARK: - Write

    func create(name: String?, profileID: String) async throws -> WhatsAppWebAccount {
        let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw WhatsAppWebAccountsRepositoryError.missingParameter("name")
        }

        let profile = AppProfile(
            id: profileID,
            displayName: trimmedName,
            isDefault: false,
            isAutoStart: false,
            createdAt: Date()
        )

        try await AppProfilesRepository.shared.persist(profile)
        let account = Self.account(from: profile)
        entries.append(account)
        entries.sort { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        NotificationCenter.default.post(name: .whatsAppWebAccountsRepositoryDidChange, object: nil)
        return account
    }

    func delete(id: UUID) async -> Bool {
        guard let profileID = entries.first(where: { $0.id == id })?.appProfileId else {
            return false
        }

        await AppProfilesRepository.shared.delete(id: profileID)
        entries.removeAll { $0.id == id }
        NotificationCenter.default.post(name: .whatsAppWebAccountsRepositoryDidChange, object: nil)
        return true
    }

    func updateAutoStart(id: UUID, isAutoStart: Bool) async -> WhatsAppWebAccount? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        var account = entries[index]
        account.isAutoStart = isAutoStart
        do {
            try await persistProfile(from: account)
            entries[index] = account
            NotificationCenter.default.post(name: .whatsAppWebAccountsRepositoryDidChange, object: nil)
            return account
        } catch {
            logger.error("Failed to update autostart for \(id): \(error.localizedDescription)")
            return nil
        }
    }

    func updateName(id: UUID, name: String?) async throws -> WhatsAppWebAccount? {
        let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw WhatsAppWebAccountsRepositoryError.missingParameter("name")
        }

        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        var account = entries[index]
        account.name = trimmedName
        try await persistProfile(from: account)
        entries[index] = account
        NotificationCenter.default.post(name: .whatsAppWebAccountsRepositoryDidChange, object: nil)
        return account
    }

    // MARK: - Helpers

    private func persistProfile(from account: WhatsAppWebAccount) async throws {
        let profile = AppProfile(
            id: account.appProfileId ?? account.id.uuidString,
            displayName: account.name,
            isDefault: account.appProfileId == AppProfile.default.id,
            isAutoStart: account.isAutoStart,
            createdAt: account.createdAt
        )
        try await AppProfilesRepository.shared.persist(profile)
    }

    private static func account(from profile: AppProfile) -> WhatsAppWebAccount {
        let accountID = UUID(uuidString: profile.id) ?? UUID()
        return WhatsAppWebAccount(
            id: accountID,
            name: profile.displayName,
            profileIdentifier: accountID,
            appProfileId: profile.id,
            createdAt: profile.createdAt,
            isAutoStart: profile.isAutoStart
        )
    }
}

// MARK: - Compatibility

extension WhatsAppWebAccount {
    func toFirestoreData() -> [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "profileIdentifier": profileIdentifier.uuidString,
            "createdAt": Timestamp(date: createdAt),
            "isAutoStart": isAutoStart,
            "updatedAt": Timestamp(date: Date()),
            "appProfileId": appProfileId as Any
        ]
    }
}

extension Notification.Name {
    static let whatsAppWebAccountsRepositoryDidChange = Notification.Name("whatsAppWebAccountsRepositoryDidChange")
}
