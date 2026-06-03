import Foundation

struct WebViewInteractiveElement: Codable, Equatable, Sendable {
    let id: String

    private enum CodingKeys: String, CodingKey {
        case marker = "$element"
        case id
    }

    init(id: String) {
        self.id = id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let marker = try container.decode(Bool.self, forKey: .marker)
        guard marker else {
            throw DecodingError.dataCorruptedError(
                forKey: .marker,
                in: container,
                debugDescription: "Expected $element == true."
            )
        }
        id = try container.decode(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(true, forKey: .marker)
        try container.encode(id, forKey: .id)
    }
}

enum WebViewInteractiveElementDetector {
    static func from(_ value: Any) -> WebViewInteractiveElement? {
        guard let dictionary = value as? [String: Any] else { return nil }
        guard let marker = dictionary["$element"] as? Bool, marker else { return nil }
        guard let id = dictionary["id"] as? String, !id.isEmpty else { return nil }
        return WebViewInteractiveElement(id: id)
    }
}
