import Foundation

enum SensitiveDataMCPToolSupport {
    static let listAuditKey = "__list__"

    static func itemMetadataObject(_ item: SensitiveDataItem) -> MCPJSONValue {
        .object([
            "id": item.id.map(MCPJSONValue.string) ?? .null,
            "key": .string(item.key),
            "kind": .string(item.kind.rawValue),
            "issueId": item.issueId.map(MCPJSONValue.string) ?? .null,
            "hasValue": .bool(item.value?.isEmpty == false)
        ])
    }

    static func itemValueObject(_ item: SensitiveDataItem) -> MCPJSONValue {
        .object([
            "id": item.id.map(MCPJSONValue.string) ?? .null,
            "key": .string(item.key),
            "kind": .string(item.kind.rawValue),
            "issueId": item.issueId.map(MCPJSONValue.string) ?? .null,
            "value": item.value.map(MCPJSONValue.string) ?? .null
        ])
    }

    static func itemListObject(_ items: [SensitiveDataItem]) -> MCPJSONValue {
        .object([
            "count": .integer(items.count),
            "items": .array(items.map(itemMetadataObject))
        ])
    }

    static func usageObject(_ usage: SensitiveDataUsage) -> MCPJSONValue {
        .object([
            "id": usage.id.map(MCPJSONValue.string) ?? .null,
            "key": .string(usage.key),
            "issueId": .string(usage.issueId),
            "reason": .string(usage.reason),
            "action": .string(usage.action.rawValue)
        ])
    }

    static func usageListObject(_ usage: [SensitiveDataUsage]) -> MCPJSONValue {
        .object([
            "count": .integer(usage.count),
            "usage": .array(usage.map(usageObject))
        ])
    }

    static func parseKinds(from call: MCPToolCall) throws -> [SensitiveDataKind]? {
        guard let rawValue = call.arguments["kinds"] else {
            return nil
        }

        guard case .array(let values) = rawValue else {
            throw MCPToolExtractionError.missingOrInvalid("kinds")
        }

        let kinds = try values.map { value in
            guard
                let rawKind = value.stringValue,
                let kind = SensitiveDataKind(rawValue: rawKind)
            else {
                throw MCPToolExtractionError.missingOrInvalid("kinds")
            }

            return kind
        }

        return kinds.isEmpty ? nil : kinds
    }

    static func usage(
        action: SensitiveDataUsageAction,
        key: String,
        issueId: String,
        reason: String
    ) -> SensitiveDataUsage {
        SensitiveDataUsage(
            id: nil,
            key: key,
            issueId: issueId,
            reason: reason,
            action: action
        )
    }

    static func searchAuditKey(for query: String) -> String {
        "__search__:\(query)"
    }
}

enum SensitiveDataMCPToolError: Error, MCPServerErrorProviding {
    case invalidArguments(String)

    var serverError: MCPServerError {
        switch self {
        case .invalidArguments(let message):
            return .invalidArguments(message)
        }
    }
}
