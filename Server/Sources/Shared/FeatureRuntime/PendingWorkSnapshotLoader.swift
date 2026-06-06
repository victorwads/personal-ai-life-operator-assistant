import Foundation

struct PendingWorkSnapshotLoader {
    let providers: [any PendingWorkProvider]

    func load() async throws -> PendingWorkSnapshot {
        var sections: [PendingWorkSection] = []

        for provider in providers {
            guard let section = try await provider.pendingWorkSection(), !section.isEmpty else {
                continue
            }
            sections.append(section)
        }

        return PendingWorkSnapshot(sections: sections)
    }
}
