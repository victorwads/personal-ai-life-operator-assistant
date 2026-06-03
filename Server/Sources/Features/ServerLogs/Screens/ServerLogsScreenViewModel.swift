import Foundation

@MainActor
final class ServerLogsScreenViewModel: ObservableObject {
    @Published private(set) var entries: [ServerLogEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedEntryID: String? {
        didSet {
            if let selectedEntry = selectedEntry {
                selectedEntrySnapshot = selectedEntry
            }
        }
    }

    var selectedEntry: ServerLogEntry? {
        if let selectedEntryID,
           let entry = entries.first(where: { $0.id == selectedEntryID }) {
            return entry
        }
        return selectedEntrySnapshot?.id == selectedEntryID ? selectedEntrySnapshot : nil
    }

    private let service: ServerLogsService
    private let toolIconProvider: @MainActor (String?) -> String?
    private var updatesTask: Task<Void, Never>?
    private var hasLoaded = false
    private var selectedEntrySnapshot: ServerLogEntry?

    init(
        service: ServerLogsService,
        toolIconProvider: @escaping @MainActor (String?) -> String?
    ) {
        self.service = service
        self.toolIconProvider = toolIconProvider
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        refresh()
    }

    func refresh() {
        Task {
            await loadEntries(showLoadingState: true)
            ensureObservation()
        }
    }

    func clearLogs() {
        Task {
            do {
                try await service.clear()
                selectedEntryID = nil
                selectedEntrySnapshot = nil
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toolIcon(for toolName: String?) -> String? {
        toolIconProvider(toolName)
    }

    private func ensureObservation() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            let updates = await service.updates()
            for await _ in updates {
                if Task.isCancelled {
                    return
                }
                await loadEntries(showLoadingState: false)
            }
        }
    }

    private func loadEntries(showLoadingState: Bool) async {
        if showLoadingState {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let latestEntries = try await service.listRecent(limit: 1_000)
            entries = latestEntries
            hasLoaded = true
            errorMessage = nil

            if let selectedEntryID,
               let selectedEntry = latestEntries.first(where: { $0.id == selectedEntryID }) {
                selectedEntrySnapshot = selectedEntry
            }
        } catch {
            errorMessage = error.localizedDescription
            if showLoadingState {
                entries = []
            }
        }
    }
}
