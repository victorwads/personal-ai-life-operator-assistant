import Foundation

@MainActor
final class AIConnectionMemoryBootstrapBridge {
    private let featureProvider: @MainActor () -> MemoriesFeature

    init(featureProvider: @escaping @MainActor () -> MemoriesFeature) {
        self.featureProvider = featureProvider
    }

    func bootstrapMessage() async -> AIConversationMessage? {
        do {
            let memories = try await featureProvider().repository.getAll()
            let sortedMemories = memories.sorted {
                $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }

            guard !sortedMemories.isEmpty else {
                return nil
            }

            return AIConversationMessage(
                role: .system,
                content: formattedBootstrapText(for: sortedMemories)
            )
        } catch {
            print("AIConnection memory bootstrap failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func formattedBootstrapText(for memories: [Memory]) -> String {
        let sections = memories.map { memory in
            """
            ## key: \(memory.key)
            \(memory.value)
            """
        }

        return """
        # Client memories

        \(sections.joined(separator: "\n\n---\n\n"))
        """
    }
}
