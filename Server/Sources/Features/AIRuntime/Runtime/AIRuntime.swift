import Foundation
import MLX
import MLXLMCommon
import MLXVLM
import Tokenizers

public struct ModelDetails: Codable, Sendable {
    public let modelType: String?
    public let layerCount: Int?
    public let totalExperts: Int?
    public let activeExperts: Int?
    public let maxContextLength: Int?

    public init(
        modelType: String? = nil,
        layerCount: Int? = nil,
        totalExperts: Int? = nil,
        activeExperts: Int? = nil,
        maxContextLength: Int? = nil
    ) {
        self.modelType = modelType
        self.layerCount = layerCount
        self.totalExperts = totalExperts
        self.activeExperts = activeExperts
        self.maxContextLength = maxContextLength
    }
}

public actor AIRuntime {
    public let configuration: AIRuntimeConfiguration

    private var modelContainer: ModelContainer?
    private var imageExtractionPromptCache: AIRuntimePromptCacheSnapshot?
    private let diskStore: AIRuntimePromptCacheDiskStore

    public init(configuration: AIRuntimeConfiguration) {
        self.configuration = configuration
        self.diskStore = AIRuntimePromptCacheDiskStore(configuration: configuration)
    }

    public func isModelLoaded() -> Bool {
        modelContainer != nil
    }

    public func loadModelDetails() -> ModelDetails {
        let configURL = configuration.modelDirectory.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return ModelDetails()
        }

        do {
            let data = try Data(contentsOf: configURL)
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return ModelDetails()
            }

            let modelType = findValue(forKey: "model_type", in: json) as? String
            let layerCount = (findValue(forKey: "num_hidden_layers", in: json) as? Int)
                          ?? (findValue(forKey: "n_layers", in: json) as? Int)
            let totalExperts = (findValue(forKey: "num_experts", in: json) as? Int)
                            ?? (findValue(forKey: "num_local_experts", in: json) as? Int)
            let activeExperts = (findValue(forKey: "num_experts_per_tok", in: json) as? Int)
                             ?? (findValue(forKey: "num_active_experts", in: json) as? Int)
                             ?? (findValue(forKey: "num_experts_per_token", in: json) as? Int)
            let maxContextLength = (findValue(forKey: "max_position_embeddings", in: json) as? Int)
                                ?? (findValue(forKey: "model_max_length", in: json) as? Int)

            return ModelDetails(
                modelType: modelType,
                layerCount: layerCount,
                totalExperts: totalExperts,
                activeExperts: activeExperts,
                maxContextLength: maxContextLength
            )
        } catch {
            return ModelDetails()
        }
    }

    public func getCacheDirectoryURL() -> URL {
        ApplicationSupportStorage
            .appSupportDirectoryURL(appending: [configuration.applicationSupportDirectoryName])
            .appendingPathComponent("PromptCaches", isDirectory: true)
    }

    private func findValue(forKey key: String, in dictionary: [String: Any]) -> Any? {
        if let value = dictionary[key] {
            return value
        }
        for (_, value) in dictionary {
            if let subDict = value as? [String: Any] {
                if let result = findValue(forKey: key, in: subDict) {
                    return result
                }
            }
        }
        return nil
    }

    public func start() async throws {
        guard modelContainer == nil else {
            return
        }

        modelContainer = try await VLMModelFactory.shared.loadContainer(
            from: configuration.modelDirectory,
            using: AIRuntimeTokenizerLoader()
        )
    }

    public func warmupImageExtractionPrompt(runtimeSettings: AIRuntimeGenerationSettings? = nil) async throws -> AIRuntimePromptCacheManifest {
        guard let modelContainer else {
            throw AIRuntimeError.modelNotLoaded
        }

        let settings = runtimeSettings ?? AIRuntimeGenerationSettings.defaultSettings
        let prompt = try AIRuntimePrompt.loadImageExtractionPrompt(
            configuration: configuration
        )
        let key = AIRuntimePromptCacheKey(
            modelId: configuration.modelId,
            promptName: prompt.name,
            promptHash: prompt.hash
        )
        var parameters = GenerateParameters(
            maxTokens: 1,
            temperature: 0
        )
        if settings.kvCacheEnabled && settings.kvCacheQuantizationEnabled {
            parameters.kvBits = settings.kvBits
            parameters.kvGroupSize = settings.kvGroupSize
        }

        let snapshot = try await modelContainer.perform { context in
            let freshCache = context.model.newCache(parameters: parameters)

            if let restored = try diskStore.load(key: key, into: freshCache) {
                return restored
            }

            let snapshot = try await Self.prefillPromptCache(
                prompt: prompt,
                key: key,
                context: context,
                parameters: parameters
            )

            try diskStore.save(snapshot: snapshot)
            return snapshot
        }

        imageExtractionPromptCache = snapshot
        return snapshot.manifest
    }

    public func clearDiskCaches() async throws {
        try diskStore.removeAll()
        imageExtractionPromptCache = nil
    }

    public func streamImageExtraction(
        imageURL: URL,
        prompt: String = "",
        systemPrompt: String? = nil,
        reasoningEnabled: Bool = false,
        maxTokens: Int = 1_000_000,
        temperature: Float = 0.0,
        topP: Float = 1.0
    ) async throws -> AsyncThrowingStream<String, Error> {
        let details = try await streamImageExtractionDetails(
            imageURL: imageURL,
            prompt: prompt,
            systemPrompt: systemPrompt,
            reasoningEnabled: reasoningEnabled,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP
        )
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in details {
                        if case .chunk(let chunk) = event {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func streamImageExtractionDetails(
        imageURL: URL,
        prompt: String = "",
        systemPrompt: String? = nil,
        runtimeSettings: AIRuntimeGenerationSettings? = nil,
        reasoningEnabled: Bool? = nil,
        maxTokens: Int? = nil,
        temperature: Float? = nil,
        topP: Float? = nil
    ) async throws -> AsyncThrowingStream<AIRuntimeStreamEvent, Error> {
        guard let modelContainer else {
            throw AIRuntimeError.modelNotLoaded
        }

        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw AIRuntimeError.invalidImage(imageURL)
        }

        guard await supportsImageInput() else {
            throw AIRuntimeError.imageInputUnsupported
        }

        let settings = runtimeSettings ?? AIRuntimeGenerationSettings.defaultSettings
        let activeReasoning = reasoningEnabled ?? settings.reasoningEnabled
        let activeMaxTokens = maxTokens ?? settings.maxTokens
        let activeTemperature = temperature ?? Float(settings.temperature)
        let activeTopP = topP ?? Float(settings.topP)

        let baseInstructions = try systemPrompt ?? AIRuntimePrompt.loadImageExtractionPrompt(
            configuration: configuration
        ).content

        let instructions: String
        if activeReasoning {
            instructions = baseInstructions + "\n\nIMPORTANT: Before returning the final answer, write down your step-by-step thinking process and reasoning inside <think>...</think> tags."
        } else {
            instructions = baseInstructions + "\n\nIMPORTANT: Do not output any thinking process or use <think> tags. Return the final answer directly."
        }

        // Apply trimming based on maxContextTokens
        let (trimmedInstructions, trimmedPrompt) = trimContextIfNeeded(
            instructions: instructions,
            prompt: prompt,
            maxContextTokens: settings.maxContextTokens
        )

        var generateParams = GenerateParameters(
            maxTokens: activeMaxTokens,
            temperature: activeTemperature,
            topP: activeTopP,
            repetitionPenalty: nil
        )
        if settings.kvCacheEnabled && settings.kvCacheQuantizationEnabled {
            generateParams.kvBits = settings.kvBits
            generateParams.kvGroupSize = settings.kvGroupSize
        }

        // The prompt-cache PoC is valid and persisted independently, but the
        // current VLM path is intentionally kept on the supported full multimodal
        // input flow. Reusing a restored text-only cache with image input is not
        // forced here until that combination is confirmed safe for this API/model.
        let session = ChatSession(
            modelContainer,
            instructions: trimmedInstructions,
            generateParameters: generateParams,
            additionalContext: activeReasoning ? nil : ["enable_thinking": false]
        )

        let details = session.streamDetails(
            to: trimmedPrompt,
            images: [.url(imageURL)],
            videos: []
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var didStartDecoding = false
                    for try await generation in details {
                        if !didStartDecoding {
                            didStartDecoding = true
                            continuation.yield(.startedDecoding)
                        }
                        switch generation {
                        case .chunk(let chunk):
                            continuation.yield(.chunk(chunk))
                        case .info(let info):
                            continuation.yield(
                                .stats(
                                    AIRuntimeGenerationStats(
                                        promptTokenCount: info.promptTokenCount,
                                        generationTokenCount: info.generationTokenCount,
                                        promptTokensPerSecond: info.promptTokensPerSecond,
                                        tokensPerSecond: info.tokensPerSecond,
                                        promptTime: info.promptTime,
                                        generateTime: info.generateTime
                                    )
                                )
                            )
                        case .toolCall:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func supportsImageInput() async -> Bool {
        guard let modelContainer else {
            return false
        }

        return await modelContainer.perform { context in
            context.model is any VLMModel
        }
    }

    private static func prefillPromptCache(
        prompt: AIRuntimePrompt,
        key: AIRuntimePromptCacheKey,
        context: ModelContext,
        parameters: GenerateParameters
    ) async throws -> AIRuntimePromptCacheSnapshot {
        let input = try await context.processor.prepare(
            input: UserInput(prompt: prompt.content)
        )

        let tokenIds = input.text.tokens.asArray(Int.self)
        let cache = context.model.newCache(parameters: parameters)

        switch try context.model.prepare(
            input,
            cache: cache,
            windowSize: parameters.prefillStepSize
        ) {
        case .tokens(let tokens):
            let result = context.model(tokens, cache: cache, state: nil)
            eval(result.logits)
        case .logits(let result):
            eval(result.logits)
        }

        let now = Date()
        let manifest = AIRuntimePromptCacheManifest(
            key: key,
            tokenCount: tokenIds.count,
            cacheFileCount: cache.reduce(0) { $0 + $1.state.count },
            layerCount: cache.count,
            metaState: cache.map(\.metaState),
            createdAt: now,
            updatedAt: now,
            restoredFromDisk: false
        )

        return AIRuntimePromptCacheSnapshot(
            manifest: manifest,
            tokenIds: tokenIds,
            cache: cache
        )
    }

    private func trimContextIfNeeded(
        instructions: String,
        prompt: String,
        maxContextTokens: Int
    ) -> (trimmedInstructions: String, trimmedPrompt: String) {
        let instructionsTokens = Int(Double(instructions.count) / 4.0)
        let promptTokens = Int(Double(prompt.count) / 4.0)

        if instructionsTokens + promptTokens <= maxContextTokens {
            return (instructions, prompt)
        }

        let availableForPrompt = max(maxContextTokens - instructionsTokens, 1024)
        let promptCharLimit = availableForPrompt * 4

        var trimmedPrompt = prompt
        if prompt.count > promptCharLimit {
            trimmedPrompt = String(prompt.prefix(promptCharLimit)) + "... [trimmed]"
        }

        let remainingForInstructions = maxContextTokens - Int(Double(trimmedPrompt.count) / 4.0)
        let instructionsCharLimit = max(remainingForInstructions, 1024) * 4

        var trimmedInstructions = instructions
        if instructions.count > instructionsCharLimit {
            trimmedInstructions = String(instructions.prefix(instructionsCharLimit)) + "... [trimmed]"
        }

        return (trimmedInstructions, trimmedPrompt)
    }
}
