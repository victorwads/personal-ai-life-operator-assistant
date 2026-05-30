import Foundation

@MainActor
final class SettingsStore {
    let profileId: String

    private let repository: any SettingsRepository
    private var scopesByName: [String: SettingsScope] = [:]
    private var listenerToken: FirestoreListenerToken?
    private var pendingSaveTasks: [String: Task<Void, Never>] = [:]
    private var pendingSaveIDs: [String: UUID] = [:]
    private var dirtyScopes: Set<String> = []
    private var isStarted = false

    init(profileId: String, repository: any SettingsRepository) {
        self.profileId = profileId
        self.repository = repository
    }

    convenience init(scope: FirebaseProfileScope, repository: (any SettingsRepository)? = nil) {
        self.init(
            profileId: scope.profileId,
            repository: repository ?? FirestoreSettingsRepository(scope: scope)
        )
    }

    func start() async throws {
        guard !isStarted else { return }

        // 1) Load initial snapshot once.
        let documents = try await repository.loadAllScopes()
        apply(documents)

        // 2) Start listening for future updates.
        startListening()
        isStarted = true
    }

    func stop() async {
        // Stop listening first. We don't want remote snapshots racing shutdown.
        stopListening()

        // Flush any pending local changes so an immediate shutdown does not lose updates.
        await flushPendingSaves()
    }

    private func startListening() {
        guard listenerToken == nil else { return }
        listenerToken = repository.observeAllScopes { [weak self] documents in
            Task { @MainActor in
                self?.apply(documents)
            }
        }
    }

    private func stopListening() {
        listenerToken?.cancel()
        listenerToken = nil
    }

    func scope(_ name: String) -> SettingsScope {
        if let scope = scopesByName[name] {
            return scope
        }

        let scope = SettingsScope(name)
        scopesByName[name] = scope
        return scope
    }

    func loadScope(_ name: String) async throws -> SettingsScope {
        let document = try await repository.loadScope(name)
        return apply(document)
    }

    func value(scope scopeName: String, key: String) -> String? {
        scope(scopeName).value(key)
    }

    func setValue(scope scopeName: String, key: String, value: String) {
        var values = scope(scopeName).snapshotValues
        values[key] = value
        scope(scopeName).update(values: values)
        dirtyScopes.insert(scopeName)
        schedulePersist(scopeName)
    }

    func deleteValue(scope scopeName: String, key: String) {
        var values = scope(scopeName).snapshotValues
        values.removeValue(forKey: key)
        scope(scopeName).update(values: values)
        dirtyScopes.insert(scopeName)
        schedulePersist(scopeName)
    }

    func saveScope(_ scopeName: String, values: [String: String]) {
        scope(scopeName).update(values: values)
        dirtyScopes.insert(scopeName)
        schedulePersist(scopeName)
    }

    @discardableResult
    private func apply(_ document: SettingsDocument) -> SettingsScope {
        let scope = scope(document.scopeName)
        scope.update(values: document.values)
        return scope
    }

    private func apply(_ documents: [SettingsDocument]) {
        for document in documents {
            // If the scope is locally dirty (or has a pending debounced save), avoid overwriting
            // in-memory values with potentially stale remote snapshots.
            if dirtyScopes.contains(document.scopeName) || pendingSaveTasks[document.scopeName] != nil {
                continue
            }
            apply(document)
        }
    }

    private func schedulePersist(_ scopeName: String) {
        pendingSaveTasks[scopeName]?.cancel()

        let repository = self.repository
        let id = UUID()
        pendingSaveIDs[scopeName] = id

        pendingSaveTasks[scopeName] = Task { [weak self] in
            // Simple per-scope debounce. Settings are written to memory synchronously; persistence happens later.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self else { return }

            let latestValues = await MainActor.run {
                self.scope(scopeName).snapshotValues
            }

            do {
                try await repository.saveScope(scopeName, values: latestValues)
                await MainActor.run {
                    guard self.pendingSaveIDs[scopeName] == id else { return }
                    self.pendingSaveTasks.removeValue(forKey: scopeName)
                    self.pendingSaveIDs.removeValue(forKey: scopeName)
                    self.dirtyScopes.remove(scopeName)
                }
            } catch {
                // TODO: Route errors to the runtime logger/telemetry surface.
                print("SettingsStore: failed to persist scope '\(scopeName)': \(error)")
            }
        }
    }

    private func flushPendingSaves() async {
        // Cancel debounced tasks; we'll persist the latest in-memory values explicitly.
        for (_, task) in pendingSaveTasks {
            task.cancel()
        }
        pendingSaveTasks.removeAll()
        pendingSaveIDs.removeAll()

        let scopesToFlush = Array(dirtyScopes)
        dirtyScopes.removeAll()

        for scopeName in scopesToFlush {
            let latestValues = scope(scopeName).snapshotValues
            do {
                try await repository.saveScope(scopeName, values: latestValues)
            } catch {
                // TODO: Route errors to the runtime logger/telemetry surface.
                print("SettingsStore: failed to flush scope '\(scopeName)' on stop: \(error)")
            }
        }
    }
}

typealias ProfileSettings = SettingsStore
