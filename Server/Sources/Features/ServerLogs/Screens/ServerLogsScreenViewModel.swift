import Foundation

@MainActor
final class ServerLogsScreenViewModel: ObservableObject {
    enum ResultFilter: String, CaseIterable, Identifiable {
        case all
        case success
        case failed

        var id: String { rawValue }
    }

    @Published private(set) var entries: [ServerLogEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var kindFilter: ServerLogKind? {
        didSet {
            guard oldValue != kindFilter, hasLoaded else { return }
            refresh()
        }
    }
    @Published var resultFilter: ResultFilter = .all {
        didSet {
            guard oldValue != resultFilter, hasLoaded else { return }
            refresh()
        }
    }
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
            let latestEntries = try await service.list(currentQuery)
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

    private var currentQuery: ServerLogQuery {
        ServerLogQuery(
            limit: 1_000,
            kind: kindFilter,
            success: successFilterValue
        )
    }

    private var successFilterValue: Bool? {
        switch resultFilter {
        case .all:
            return nil
        case .success:
            return true
        case .failed:
            return false
        }
    }
}
