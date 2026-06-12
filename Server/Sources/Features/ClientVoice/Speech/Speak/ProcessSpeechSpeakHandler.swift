import Foundation

final class ProcessSpeechSpeakHandler: SpeechSpeakHandler, @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process

    private var finished = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(process: Process) {
        self.process = process
    }

    func start() throws {
        process.terminationHandler = { [weak self] launchedProcess in
            Task { @MainActor in
                self?.handleTermination(status: launchedProcess.terminationStatus)
            }
        }

        do {
            try process.run()
        } catch {
            finish()
            throw error
        }
    }

    override func await() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if finished {
                lock.unlock()
                continuation.resume()
                return
            }

            self.continuation = continuation
            lock.unlock()
        }
    }

    override func cancel() {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        lock.unlock()

        process.terminate()
    }

    private func handleTermination(status _: Int32) {
        finish()
    }

    private func finish() {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }

        finished = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume()
    }
}
