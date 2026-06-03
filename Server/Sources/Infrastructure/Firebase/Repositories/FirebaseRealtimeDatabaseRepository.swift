import Foundation
import FirebaseDatabase

final class FirebaseRealtimeDatabaseRepository {
    private let reference: DatabaseReference

    init(path: String, database: Database = .database()) {
        reference = database.reference(withPath: path)
    }

    func observeBool(_ onChange: @escaping (Bool) -> Void) -> RealtimeDatabaseListenerToken {
        let handle = reference.observe(.value) { snapshot in
            onChange(Self.decodeBool(from: snapshot))
        }

        return RealtimeDatabaseListenerToken { [reference] in
            reference.removeObserver(withHandle: handle)
        }
    }

    func setBool(_ value: Bool) async throws {
        try await reference.setValue(value)
    }

    func getBool() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            reference.observeSingleEvent(
                of: .value,
                andPreviousSiblingKeyWith: { snapshot, _ in
                    continuation.resume(returning: Self.decodeBool(from: snapshot))
                },
                withCancel: { error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }

    private static func decodeBool(from snapshot: DataSnapshot) -> Bool {
        if let boolValue = snapshot.value as? Bool {
            return boolValue
        }

        if let numberValue = snapshot.value as? NSNumber {
            return numberValue.boolValue
        }

        if let stringValue = snapshot.value as? String {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return ["true", "1", "yes", "on"].contains(normalized)
        }

        return false
    }
}
