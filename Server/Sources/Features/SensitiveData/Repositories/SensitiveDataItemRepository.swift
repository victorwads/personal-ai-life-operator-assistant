import Foundation

final class FirestoreSensitiveDataRepository: FirestoreRepository<SensitiveDataItem> {
    init(scope: FirebaseProfileScope) {
        super.init(
            entityName: "SensitiveDataItem",
            path: .profileScoped(scope: scope, collection: "SensitiveData")
        )
    }

    func item(forKey key: String, includeDeleted: Bool = false) async throws -> SensitiveDataItem? {
        try await query(
            matching: ["key": key],
            limit: 1,
            includeDeleted: includeDeleted
        ).first
    }

    func list(kinds: [SensitiveDataKind]? = nil, includeDeleted: Bool = false) async throws -> [SensitiveDataItem] {
        let items = try await getAll(includeDeleted: includeDeleted)
        return filter(items, kinds: kinds)
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    func search(query: String, kinds: [SensitiveDataKind]?) async throws -> [SensitiveDataItem] {
        let normalizedQuery = query.localizedLowercase
        return try await list(kinds: kinds)
            .filter { item in
                item.key.localizedLowercase.contains(normalizedQuery)
                    || item.kind.rawValue.localizedLowercase.contains(normalizedQuery)
            }
    }

    func documentID(forKey key: String) -> String {
        let encoded = Data(key.utf8).base64EncodedString()
        return encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func filter(
        _ items: [SensitiveDataItem],
        kinds: [SensitiveDataKind]?
    ) -> [SensitiveDataItem] {
        guard let kinds, !kinds.isEmpty else {
            return items
        }

        let allowedKinds = Set(kinds)
        return items.filter { allowedKinds.contains($0.kind) }
    }
}
