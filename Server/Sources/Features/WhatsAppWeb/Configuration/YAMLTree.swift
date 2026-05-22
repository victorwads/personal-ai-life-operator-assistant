import Foundation
import Yams

enum YAMLTreeError: LocalizedError {
    case invalidRoot

    var errorDescription: String? {
        switch self {
        case .invalidRoot:
            return "Invalid YAML root. Expected an object at the top level."
        }
    }
}

/// A Sendable wrapper for YAML-decoded values so we can safely store the raw tree.
enum AnySendable: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnySendable])
    case object([String: AnySendable])
}

struct YAMLTree: Sendable, Equatable {
    let root: [String: AnySendable]

    static func parse(yaml: String) throws -> YAMLTree {
        let loaded = try Yams.load(yaml: yaml)
        guard let dict = loaded as? [String: Any] else {
            throw YAMLTreeError.invalidRoot
        }
        return YAMLTree(root: AnySendableCoercion.object(from: dict))
    }
}

enum AnySendableCoercion {
    static func object(from dict: [String: Any]) -> [String: AnySendable] {
        var out: [String: AnySendable] = [:]
        out.reserveCapacity(dict.count)
        for (key, entryValue) in dict {
            out[key] = value(from: entryValue)
        }
        return out
    }

    static func value(from any: Any?) -> AnySendable {
        guard let any else { return .null }
        if any is NSNull { return .null }
        if let bool = any as? Bool { return .bool(bool) }
        if let int = any as? Int { return .int(int) }
        if let double = any as? Double { return .double(double) }
        if let number = any as? NSNumber {
            // NSNumber can be bool/int/double; best-effort.
            let type = String(cString: number.objCType)
            if type == "c" { return .bool(number.boolValue) }
            let doubleValue = number.doubleValue
            let intValue = number.intValue
            if fabs(doubleValue - Double(intValue)) < .ulpOfOne {
                return .int(intValue)
            }
            return .double(doubleValue)
        }
        if let string = any as? String { return .string(string) }
        if let array = any as? [Any] { return .array(array.map { value(from: $0) }) }
        if let dict = any as? [String: Any] { return .object(object(from: dict)) }
        return .string(String(describing: any))
    }
}
