import Foundation

enum SampleDebugItems {
    static var items: [DebugObjectItem] {
        struct SampleValue: Codable {
            let id: UUID
            let name: String
            let createdAt: Date
            let tags: [String]
        }

        return [
            DebugObjectItem(
                title: "Model",
                value: SampleValue(
                    id: UUID(),
                    name: "Example",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    tags: ["debug", "shared-ui"]
                )
            ),
            DebugObjectItem(
                title: "Raw Response",
                value: """
                {
                  "id": "resp_123",
                  "message": "Keep this raw formatting exactly as-is."
                }
                """
            )
        ]
    }
}
