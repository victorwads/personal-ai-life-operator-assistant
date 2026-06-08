import Foundation

protocol AIResourceUsageRepository: Sendable {
    var currentUse: AIResourceUsageDocument { get }
    var sessionUse: AIResourceUsageDocument { get }
    var pendingUnsyncedUse: AIResourceUsageDocument? { get }

    func add(_ addition: AIResourceUsageAddition) async
    func flush() async
    func clearSessionUse()
    func loadCurrentUse() async throws -> AIResourceUsageDocument
}

final actor FirestoreAIResourceUsageRepository: AIResourceUsageRepository {

    nonisolated func clearSessionUse() {
    }
    
    private let profileId: String
    private let repository: FirestoreRepository<AIResourceUsageDocument>

    private nonisolated(unsafe) var totalCache = AIResourceUsageDocument()
    private nonisolated(unsafe) var toSendCache = AIResourceUsageDocument()
    private nonisolated(unsafe) var sessionCache = AIResourceUsageDocument()

    private nonisolated(unsafe) var currentUseSnapshot = AIResourceUsageDocument()
    private nonisolated(unsafe) var sessionUseSnapshot = AIResourceUsageDocument()

    private nonisolated(unsafe) var lastSent = Date.distantPast

    private let minSecondsBetweenUpdates: TimeInterval = 5
    private let maxSecondsWithoutSending: TimeInterval = 60 * 5
    private let minRequestsToSend = 1

    init(profileId: String) {
        self.profileId = profileId
        self.repository = FirestoreRepository<AIResourceUsageDocument>(
            entityName: "AIResourceUsage",
            path: .profileScoped(
                scope: FirebaseProfileScope(profileId: profileId),
                collection: "AIResourceUsage"
            ),
            readSource: .default,
            warmCacheOnInit: false
        )
    }

    nonisolated var currentUse: AIResourceUsageDocument {
        currentUseSnapshot
    }

    nonisolated var sessionUse: AIResourceUsageDocument {
        sessionUseSnapshot
    }

    nonisolated var pendingUnsyncedUse: AIResourceUsageDocument? {
        toSendCache
    }

    func loadCurrentUse() async throws -> AIResourceUsageDocument {
        let doc = try await repository.getById("usage") ?? AIResourceUsageDocument()
        totalCache = doc
        currentUseSnapshot = doc
        return doc
    }

    func clearSessionUse() async {
        sessionCache = AIResourceUsageDocument()
        sessionUseSnapshot = sessionCache
    }

    func add(_ addition: AIResourceUsageAddition) async {
        let normalized = Self.normalizedUsage(from: addition)

        apply(normalized, to: &totalCache)
        apply(normalized, to: &toSendCache)
        apply(normalized, to: &sessionCache)

        currentUseSnapshot = totalCache
        sessionUseSnapshot = sessionCache

        await flushIfNeeded()
    }

    func flush() async {
        let fields = Self.incrementFields(from: toSendCache)
        guard !fields.isEmpty else { return }

        do {
            try await repository.increment(id: "usage", fields: fields)
            toSendCache = AIResourceUsageDocument()
            lastSent = Date()
        } catch {
            print("AIResourceUsageRepository flush failed: \(error.localizedDescription)")
        }
    }

    private func flushIfNeeded() async {
        let seconds = Date().timeIntervalSince(lastSent)

        let shouldFlush =
            seconds >= maxSecondsWithoutSending ||
            (
                seconds >= minSecondsBetweenUpdates &&
                toSendCache.total.requests >= minRequestsToSend
            )

        guard shouldFlush else { return }
        await flush()
    }

    static func normalizedUsage(from addition: AIResourceUsageAddition) -> AIResourceUsageDocument {
        let usage = addition.usage
        let totalTokens = usage.totalTokens ?? ((usage.promptTokens ?? 0) + (usage.completionTokens ?? 0) + (usage.reasoningTokens ?? 0))
        let tokenUsage = AIResourceTokenUsage(
            requests: 1,
            inputTokens: usage.promptTokens ?? 0,
            outputTokens: usage.completionTokens ?? 0,
            reasoningTokens: usage.reasoningTokens ?? 0,
            cachedInputTokens: usage.cachedInputTokens ?? 0,
            totalTokens: totalTokens
        )

        var document = AIResourceUsageDocument()
        switch addition.pool {
        case .total:
            document.total = tokenUsage
        case .assistant:
            document.total = tokenUsage
            document.assistant = tokenUsage
        case .imageExtraction:
            document.total = tokenUsage
            document.imageExtraction = tokenUsage
        }

        return document
    }

    private static func incrementFields(from document: AIResourceUsageDocument) -> [String: Int] {
        var fields: [String: Int] = [:]
        addIncrementFields(prefix: "total", usage: document.total, into: &fields)
        addIncrementFields(prefix: "assistant", usage: document.assistant, into: &fields)
        addIncrementFields(prefix: "imageExtraction", usage: document.imageExtraction, into: &fields)
        return fields
    }

    private static func addIncrementFields(prefix: String, usage: AIResourceTokenUsage, into fields: inout [String: Int]) {
        let pairs: [(String, Int)] = [
            ("requests", usage.requests),
            ("inputTokens", usage.inputTokens),
            ("outputTokens", usage.outputTokens),
            ("reasoningTokens", usage.reasoningTokens),
            ("cachedInputTokens", usage.cachedInputTokens),
            ("totalTokens", usage.totalTokens)
        ]

        for (key, value) in pairs where value != 0 {
            fields["\(prefix).\(key)"] = value
        }
    }

    private func apply(_ document: AIResourceUsageDocument, to target: inout AIResourceUsageDocument) {
        target.total.requests += document.total.requests
        target.total.inputTokens += document.total.inputTokens
        target.total.outputTokens += document.total.outputTokens
        target.total.reasoningTokens += document.total.reasoningTokens
        target.total.cachedInputTokens += document.total.cachedInputTokens
        target.total.totalTokens += document.total.totalTokens

        target.assistant.requests += document.assistant.requests
        target.assistant.inputTokens += document.assistant.inputTokens
        target.assistant.outputTokens += document.assistant.outputTokens
        target.assistant.reasoningTokens += document.assistant.reasoningTokens
        target.assistant.cachedInputTokens += document.assistant.cachedInputTokens
        target.assistant.totalTokens += document.assistant.totalTokens

        target.imageExtraction.requests += document.imageExtraction.requests
        target.imageExtraction.inputTokens += document.imageExtraction.inputTokens
        target.imageExtraction.outputTokens += document.imageExtraction.outputTokens
        target.imageExtraction.reasoningTokens += document.imageExtraction.reasoningTokens
        target.imageExtraction.cachedInputTokens += document.imageExtraction.cachedInputTokens
        target.imageExtraction.totalTokens += document.imageExtraction.totalTokens
    }
}

final actor NoopAIResourceUsageRepository: AIResourceUsageRepository {

    nonisolated func clearSessionUse() {
    }
    
    private nonisolated(unsafe) var currentUseSnapshot = AIResourceUsageDocument()
    private nonisolated(unsafe) var sessionUseSnapshot = AIResourceUsageDocument()

    nonisolated var currentUse: AIResourceUsageDocument {
        currentUseSnapshot
    }

    nonisolated var sessionUse: AIResourceUsageDocument {
        sessionUseSnapshot
    }

    nonisolated var pendingUnsyncedUse: AIResourceUsageDocument? {
        nil
    }

    func loadCurrentUse() async throws -> AIResourceUsageDocument {
        currentUseSnapshot
    }

    func add(_ addition: AIResourceUsageAddition) async {
        let normalized = FirestoreAIResourceUsageRepository.normalizedUsage(from: addition)
        currentUseSnapshot = merge(currentUseSnapshot, with: normalized)
        sessionUseSnapshot = merge(sessionUseSnapshot, with: normalized)
    }

    func flush() async {}

    func clearSessionUse() async {
        sessionUseSnapshot = AIResourceUsageDocument()
    }

    private func merge(_ lhs: AIResourceUsageDocument, with rhs: AIResourceUsageDocument) -> AIResourceUsageDocument {
        var document = lhs
        document.total.requests += rhs.total.requests
        document.total.inputTokens += rhs.total.inputTokens
        document.total.outputTokens += rhs.total.outputTokens
        document.total.reasoningTokens += rhs.total.reasoningTokens
        document.total.cachedInputTokens += rhs.total.cachedInputTokens
        document.total.totalTokens += rhs.total.totalTokens

        document.assistant.requests += rhs.assistant.requests
        document.assistant.inputTokens += rhs.assistant.inputTokens
        document.assistant.outputTokens += rhs.assistant.outputTokens
        document.assistant.reasoningTokens += rhs.assistant.reasoningTokens
        document.assistant.cachedInputTokens += rhs.assistant.cachedInputTokens
        document.assistant.totalTokens += rhs.assistant.totalTokens

        document.imageExtraction.requests += rhs.imageExtraction.requests
        document.imageExtraction.inputTokens += rhs.imageExtraction.inputTokens
        document.imageExtraction.outputTokens += rhs.imageExtraction.outputTokens
        document.imageExtraction.reasoningTokens += rhs.imageExtraction.reasoningTokens
        document.imageExtraction.cachedInputTokens += rhs.imageExtraction.cachedInputTokens
        document.imageExtraction.totalTokens += rhs.imageExtraction.totalTokens

        return document
    }
}
