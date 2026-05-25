import Foundation
import FirebaseFirestore

public struct FirestoreCodableMapper {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.encoder = encoder ?? Self.makeEncoder()
        self.decoder = decoder ?? Self.makeDecoder()
    }

    public func encode<Model: Encodable>(_ model: Model, entityName: String) throws -> [String: Any] {
        do {
            let data = try encoder.encode(model)
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            guard let dictionary = object as? [String: Any] else {
                throw FirestoreRepositoryError.encodingFailed(entity: entityName)
            }
            return dictionary
        } catch let error as FirestoreRepositoryError {
            throw error
        } catch {
            throw FirestoreRepositoryError.encodingFailed(entity: entityName)
        }
    }

    public func decode<Model: Decodable>(
        _ modelType: Model.Type,
        from data: [String: Any],
        documentId: String? = nil,
        entityName: String
    ) throws -> Model {
        do {
            let payload = try sanitizedPayload(from: injectingDocumentId(documentId, into: data))
            return try decoder.decode(Model.self, from: payload)
        } catch let error as FirestoreRepositoryError {
            throw error
        } catch {
            throw FirestoreRepositoryError.decodingFailed(entity: entityName)
        }
    }

    private func injectingDocumentId(_ documentId: String?, into data: [String: Any]) -> [String: Any] {
        guard let documentId, !documentId.isEmpty else {
            return data
        }

        var payload = data
        if payload["id"] == nil || payload["id"] is NSNull {
            payload["id"] = documentId
        }
        return payload
    }

    private func sanitizedPayload(from data: [String: Any]) throws -> Data {
        let jsonObject = sanitize(value: data)
        guard JSONSerialization.isValidJSONObject(jsonObject) else {
            throw FirestoreRepositoryError.decodingFailed(entity: "model")
        }
        return try JSONSerialization.data(withJSONObject: jsonObject, options: [])
    }

    private func sanitize(value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            return dictionary.mapValues { sanitize(value: $0) }
        case let array as [Any]:
            return array.map { sanitize(value: $0) }
        case let timestamp as Timestamp:
            return timestamp.dateValue().timeIntervalSince1970
        case let date as Date:
            return date.timeIntervalSince1970
        case let nsNull as NSNull:
            return nsNull
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case let bool as Bool:
            return bool
        default:
            return value
        }
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }
}
