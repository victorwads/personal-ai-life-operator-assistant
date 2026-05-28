import Foundation

final class WhatsAppCrawlerPolling {
    private let worker: WhatsAppCrawlerWorker
    private let intervalNanoseconds: UInt64
    private var pollingTask: Task<Void, Never>?

    init(worker: WhatsAppCrawlerWorker, intervalNanoseconds: UInt64 = 30_000_000_000) {
        self.worker = worker
        self.intervalNanoseconds = intervalNanoseconds
    }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [worker, intervalNanoseconds] in
            while !Task.isCancelled {
                // TODO: Future orchestration owns business rules: run a full
                // cycle, then wait pollingIntervalSeconds after it finishes.
                // It should not start overlapping cycles on a fixed timer.
                // Message refresh decisions should flow through an explicit
                // shouldRefreshChatMessages function; integration services
                // should expose raw capabilities only.
                _ = await worker.runCycle()
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
