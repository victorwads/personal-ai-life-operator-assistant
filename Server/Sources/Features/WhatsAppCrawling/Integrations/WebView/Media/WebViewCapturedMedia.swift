import Foundation

struct WebViewCapturedMedia: Equatable, Sendable {
    let mimeType: String?
    let size: Int?
    let timestamp: Int?
    let base64: String

    static func from(_ value: Any?) -> WebViewCapturedMedia? {
        guard let object = dictionary(from: value) else { return nil }
        guard let base64 = nonEmptyString(object["base64"]) else { return nil }

        return WebViewCapturedMedia(
            mimeType: object["mimeType"] as? String,
            size: intValue(from: object["size"]),
            timestamp: intValue(from: object["timestamp"]),
            base64: base64
        )
    }

    private static func dictionary(from value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? NSDictionary {
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                guard let key = key as? String else { continue }
                result[key] = value
            }
            return result
        }
        return nil
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }

    private static func intValue(from value: Any?) -> Int? {
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? Int {
            return value
        }
        if let value = value as? Double {
            return Int(value)
        }
        return nil
    }
}
