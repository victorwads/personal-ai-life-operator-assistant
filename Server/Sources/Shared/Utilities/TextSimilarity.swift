import Foundation

struct TextSimilarity {
    /// Calculates a similarity score between a query and a text.
    /// Returns a value between 0.0 (no match) and 1.0 (exact match or query is fully contained in text).
    static func score(query: String, text: String?) -> Double {
        guard let text else { return 0 }

        let normalizedQuery = normalizedSearchText(query)
        let normalizedText = normalizedSearchText(text)
        guard !normalizedQuery.isEmpty, !normalizedText.isEmpty else {
            return 0
        }

        if normalizedText.contains(normalizedQuery) {
            return 1
        }

        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        guard !queryTokens.isEmpty else {
            return 0
        }

        let textTokens = Set(normalizedText.split(separator: " ").map(String.init))
        let matchedTokens = queryTokens.filter { queryToken in
            textTokens.contains(where: { textToken in
                textToken == queryToken || textToken.contains(queryToken) || queryToken.contains(textToken)
            })
        }.count

        return Double(matchedTokens) / Double(queryTokens.count)
    }

    /// Normalizes text by folding case/diacritics and replacing non-alphanumeric characters with spaces.
    static func normalizedSearchText(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
        let normalizedScalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        return String(normalizedScalars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
