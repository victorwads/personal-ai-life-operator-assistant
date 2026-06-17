import Foundation
import AppKit
import Combine

public enum ExecutionPhase: String, Sendable, CaseIterable {
    case unloaded = "Model Unloaded"
    case loadingModel = "Loading Model"
    case modelReady = "Model Ready"
    case processingPrompt = "Processing Prompt"
    case decodingTokens = "Generating Output"
    case complete = "Complete"
    case failed = "Failed"
}

@MainActor
final class AIRuntimePoCViewModel: ObservableObject {
    @Published var runtimeState = "Idle"
    @Published var executionPhase: ExecutionPhase = .unloaded
    @Published var cacheState = "Not prepared"
    @Published var cacheDetails = ""
    @Published var selectedImageURL: URL?
    @Published var output = ""
    @Published var thinkingOutput = ""
    @Published var finalOutput = ""
    @Published var reasoningEnabled = false
    @Published var maxTokens = 4096
    @Published var temperature: Float = 0.8
    @Published var topP: Float = 0.95
    @Published var modelDetails: ModelDetails? = nil
    
    @Published var errorMessage: String?
    @Published var isRunning = false
    @Published var tokensPerSecondText = "-"
    @Published var promptTokensPerSecondText = "-"
    @Published var generationTokenCountText = "-"
    @Published var promptTokenCountText = "-"
    
    // Real-time metrics
    @Published var generatedTokensCount = 0
    @Published var generationSecondsElapsed = 0.0
    @Published var realTimeTokensPerSecond = 0.0
    @Published var lastStats: AIRuntimeGenerationStats? = nil
    
    private var decodingStartTime: Date?
    private var decodingTimer: Timer?

    let runtime: AIRuntime
    private(set) var settings: AIRuntimeSettingsWrapper?
    private var cancellables = Set<AnyCancellable>()

    init(runtime: AIRuntime, settings: AIRuntimeSettingsWrapper? = nil) {
        self.runtime = runtime
        self.settings = settings
        
        if let settings {
            self.reasoningEnabled = settings.reasoningEnabled
            self.maxTokens = settings.maxTokens
            self.temperature = settings.temperature
            self.topP = settings.topP
        }
        
        setupSettingsPersistence()

        Task {
            let details = await runtime.loadModelDetails()
            let isLoaded = await runtime.isModelLoaded()
            await MainActor.run {
                self.modelDetails = details
                self.executionPhase = isLoaded ? .modelReady : .unloaded
            }
        }
    }

    private func setupSettingsPersistence() {
        guard let settings = settings else { return }
        
        $reasoningEnabled
            .dropFirst()
            .sink { settings.reasoningEnabled = $0 }
            .store(in: &cancellables)
            
        $maxTokens
            .dropFirst()
            .sink { settings.maxTokens = $0 }
            .store(in: &cancellables)
            
        $temperature
            .dropFirst()
            .sink { settings.temperature = $0 }
            .store(in: &cancellables)
            
        $topP
            .dropFirst()
            .sink { settings.topP = $0 }
            .store(in: &cancellables)
    }

    deinit {
        decodingTimer?.invalidate()
    }

    var modelPath: String {
        runtime.configuration.modelDirectory.path
    }

    var displayDecodeSpeed: String {
        if isRunning && executionPhase == .decodingTokens {
            return String(format: "%.2f tok/s (Real-time)", realTimeTokensPerSecond)
        }
        return tokensPerSecondText
    }

    var displayGeneratedTokens: String {
        if isRunning && executionPhase == .decodingTokens {
            return "\(generatedTokensCount) tokens"
        }
        return generationTokenCountText
    }

    var displayElapsedTime: String {
        if isRunning {
            if executionPhase == .decodingTokens || executionPhase == .processingPrompt {
                return String(format: "%.1f s", generationSecondsElapsed)
            }
            return "-"
        }
        if let stats = lastStats {
            return String(format: "%.3f s (Prompt: %.3f s, Decode: %.3f s)", stats.promptTime + stats.generateTime, stats.promptTime, stats.generateTime)
        }
        return "-"
    }

    var displayTotalTokens: String {
        if isRunning && executionPhase == .decodingTokens {
            let prompt = Int(promptTokenCountText) ?? 0
            return "\(prompt + generatedTokensCount) tokens"
        }
        if let stats = lastStats {
            return "\(stats.promptTokenCount + stats.generationTokenCount) tokens"
        }
        return "-"
    }

    private func stopDecodingTimer() {
        decodingTimer?.invalidate()
        decodingTimer = nil
    }

    func startRuntime() {
        guard !isRunning else { return }

        isRunning = true
        runtimeState = "Starting runtime..."
        executionPhase = .loadingModel
        errorMessage = nil

        Task {
            do {
                try await runtime.start()
                let details = await runtime.loadModelDetails()
                await MainActor.run {
                    self.modelDetails = details
                    self.runtimeState = "Runtime loaded"
                    self.executionPhase = .modelReady
                    self.isRunning = false
                }
            } catch {
                await handle(error, runtimeState: "Runtime failed")
            }
        }
    }

    func warmupCache() {
        guard !isRunning else { return }

        isRunning = true
        runtimeState = "Warming or restoring prompt cache..."
        executionPhase = .processingPrompt
        errorMessage = nil

        Task {
            do {
                let manifest = try await runtime.warmupImageExtractionPrompt()
                let manifestText = Self.prettyJSON(manifest)

                await MainActor.run {
                    self.cacheState = manifest.restoredFromDisk ? "Restored from disk" : "Freshly created"
                    self.cacheDetails = manifestText
                    self.output = manifestText
                    self.thinkingOutput = ""
                    self.finalOutput = manifestText
                    self.runtimeState = "Prompt cache ready"
                    self.executionPhase = .complete
                    self.isRunning = false
                }
            } catch {
                await handle(error, runtimeState: "Prompt cache failed")
            }
        }
    }

    func selectImageResult(_ url: URL) {
        selectedImageURL = url
        errorMessage = nil
    }

    func extractImage() {
        guard !isRunning else { return }
        guard let selectedImageURL else {
            errorMessage = "Select an image before running extraction."
            return
        }

        isRunning = true
        runtimeState = "Extracting image..."
        executionPhase = .processingPrompt
        output = ""
        thinkingOutput = ""
        finalOutput = ""
        errorMessage = nil
        generatedTokensCount = 0
        generationSecondsElapsed = 0.0
        realTimeTokensPerSecond = 0.0
        decodingStartTime = nil
        stopDecodingTimer()
        lastStats = nil

        Task {
            do {
                let stream = try await runtime.streamImageExtractionDetails(
                    imageURL: selectedImageURL,
                    reasoningEnabled: reasoningEnabled,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: topP
                )
                for try await event in stream {
                    await MainActor.run {
                        switch event {
                        case .startedDecoding:
                            self.executionPhase = .decodingTokens
                            self.decodingStartTime = Date()
                            self.decodingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                                guard let self = self, let startTime = self.decodingStartTime else { return }
                                let elapsed = Date().timeIntervalSince(startTime)
                                self.generationSecondsElapsed = elapsed
                                if elapsed > 0 {
                                    self.realTimeTokensPerSecond = Double(self.generatedTokensCount) / elapsed
                                }
                            }
                        case .chunk(let chunk):
                            self.generatedTokensCount += 1
                            if let startTime = self.decodingStartTime {
                                let elapsed = Date().timeIntervalSince(startTime)
                                self.generationSecondsElapsed = elapsed
                                self.realTimeTokensPerSecond = Double(self.generatedTokensCount) / elapsed
                            }
                            self.output += chunk
                            self.parseOutput(self.output)
                        case .stats(let stats):
                            self.stopDecodingTimer()
                            self.lastStats = stats
                            self.tokensPerSecondText = Self.formatRate(stats.tokensPerSecond)
                            self.promptTokensPerSecondText = Self.formatRate(stats.promptTokensPerSecond)
                            self.generationTokenCountText = "\(stats.generationTokenCount)"
                            self.promptTokenCountText = "\(stats.promptTokenCount)"
                        }
                    }
                }

                await MainActor.run {
                    self.stopDecodingTimer()
                    self.runtimeState = "Extraction complete"
                    self.executionPhase = .complete
                    self.isRunning = false
                }
            } catch {
                self.stopDecodingTimer()
                await handle(error, runtimeState: "Extraction failed")
            }
        }
    }

    func clearCache() {
        guard !isRunning else { return }

        isRunning = true
        runtimeState = "Clearing cache..."
        errorMessage = nil

        Task {
            do {
                try await runtime.clearDiskCaches()
                await MainActor.run {
                    self.stopDecodingTimer()
                    self.cacheState = "Not prepared"
                    self.cacheDetails = ""
                    self.output = ""
                    self.thinkingOutput = ""
                    self.finalOutput = ""
                    self.tokensPerSecondText = "-"
                    self.promptTokensPerSecondText = "-"
                    self.generationTokenCountText = "-"
                    self.promptTokenCountText = "-"
                    self.generatedTokensCount = 0
                    self.generationSecondsElapsed = 0.0
                    self.realTimeTokensPerSecond = 0.0
                    self.lastStats = nil
                    self.runtimeState = "Cache cleared"
                    self.isRunning = false
                }
            } catch {
                await handle(error, runtimeState: "Cache clear failed")
            }
        }
    }

    private func handle(_ error: Error, runtimeState: String) async {
        await MainActor.run {
            self.stopDecodingTimer()
            self.runtimeState = runtimeState
            self.errorMessage = error.localizedDescription
            self.executionPhase = .failed
            self.isRunning = false
        }
    }

    private func parseOutput(_ raw: String) {
        let thinkStartTags = ["<think>", "<thinking>"]
        let thinkEndTags = ["</think>", "</thinking>"]
        
        var foundStartTag: String? = nil
        var foundStartIndex: String.Index? = nil
        
        for tag in thinkStartTags {
            if let range = raw.range(of: tag) {
                foundStartTag = tag
                foundStartIndex = range.upperBound
                break
            }
        }
        
        guard let startIndex = foundStartIndex, let startTag = foundStartTag else {
            if raw.starts(with: "<") && !"<think>".starts(with: raw) && !"<thinking>".starts(with: raw) {
                self.thinkingOutput = ""
                self.finalOutput = raw
            } else if raw.starts(with: "<") {
                self.thinkingOutput = raw
                self.finalOutput = ""
            } else {
                self.thinkingOutput = ""
                self.finalOutput = raw
            }
            return
        }
        
        var foundEndIndex: String.Index? = nil
        var foundEndTagLength = 0
        for tag in thinkEndTags {
            if let range = raw.range(of: tag) {
                foundEndIndex = range.lowerBound
                foundEndTagLength = tag.count
                break
            }
        }
        
        if let endIndex = foundEndIndex {
            self.thinkingOutput = String(raw[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let afterEndIndex = raw.index(endIndex, offsetBy: foundEndTagLength)
            self.finalOutput = String(raw[afterEndIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.thinkingOutput = String(raw[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            self.finalOutput = ""
        }
    }

    private static func prettyJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(value)
        return data.map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    private static func formatRate(_ value: Double) -> String {
        String(format: "%.2f tok/s", value)
    }

    func openCacheFolder() {
        Task {
            let url = await runtime.getCacheDirectoryURL()
            NSWorkspace.shared.open(url)
        }
    }
}
