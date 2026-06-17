import SwiftUI
import UniformTypeIdentifiers

struct AIRuntimePoCScreen: View {
    @StateObject private var viewModel: AIRuntimePoCViewModel
    @State private var isImportingImage = false

    init(runtime: AIRuntime, settings: AIRuntimeSettingsWrapper? = nil) {
        _viewModel = StateObject(
            wrappedValue: AIRuntimePoCViewModel(runtime: runtime, settings: settings)
        )
    }

    var body: some View {
        FeatureScreenContainer {
            DSFeatureHeader(
                title: "AI PoC",
                subtitle: "Global AIRuntime proof of concept for local MLX model loading, prompt-cache warmup/restore, and streamed image extraction."
            ) {
                HStack(spacing: 8) {
                    Button("Start Runtime") {
                        viewModel.startRuntime()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Warmup / Restore Cache") {
                        viewModel.warmupCache()
                    }
                    .disabled(viewModel.isRunning)

                    Button("Select Image") {
                        isImportingImage = true
                    }
                    .disabled(viewModel.isRunning)

                    Button("Extract Image") {
                        viewModel.extractImage()
                    }
                    .disabled(viewModel.isRunning || viewModel.selectedImageURL == nil)

                    Button("Clear Cache") {
                        viewModel.clearCache()
                    }
                    .disabled(viewModel.isRunning)

                    Button("Open Cache Folder") {
                        viewModel.openCacheFolder()
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DSTitledSection(title: "Pipeline Execution Phase") {
                        HStack(spacing: 0) {
                            stepView(title: "1. Load Model", status: loadModelStatus)
                            stepConnector(status: loadModelStatus)
                            stepView(title: "2. Prompt Prefill", status: promptPrefillStatus)
                            stepConnector(status: promptPrefillStatus)
                            stepView(title: "3. Generate Output", status: generateOutputStatus)
                        }
                        .padding(.vertical, 8)
                    }

                    DSTitledSection(title: "Runtime Metadata") {
                        VStack(alignment: .leading, spacing: 12) {
                            labeledValue("Model path", value: viewModel.modelPath, monospaced: true)
                            
                            Divider()
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                                labeledValue("Model Type", value: viewModel.modelDetails?.modelType ?? "Parsing config.json...")
                                if let layers = viewModel.modelDetails?.layerCount {
                                    labeledValue("Layers Loaded", value: "\(layers) layers")
                                } else {
                                    labeledValue("Layers Loaded", value: "Unknown")
                                }
                                if let total = viewModel.modelDetails?.totalExperts, let active = viewModel.modelDetails?.activeExperts {
                                    labeledValue("MoE Experts", value: "\(active) active / \(total) total")
                                } else {
                                    labeledValue("MoE Experts", value: "Non-MoE / Dense")
                                }
                                
                                labeledValue("Runtime State", value: viewModel.runtimeState)
                                labeledValue("Prompt Cache State", value: viewModel.cacheState)
                                if let maxCtx = viewModel.modelDetails?.maxContextLength {
                                    let formattedCtx = NumberFormatter.localizedString(from: NSNumber(value: maxCtx), number: .decimal)
                                    labeledValue("Context Limit", value: "\(formattedCtx) tokens")
                                } else {
                                    labeledValue("Context Limit", value: "Unknown")
                                }

                                labeledValue("Selected Image", value: viewModel.selectedImageURL?.lastPathComponent ?? "No image selected", monospaced: true)
                            }
                            
                            Divider()
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                                labeledValue("Prefill Speed", value: viewModel.promptTokensPerSecondText)
                                labeledValue("Decode Speed", value: viewModel.displayDecodeSpeed)
                                labeledValue("Elapsed Time", value: viewModel.displayElapsedTime)
                                
                                labeledValue("Prompt Tokens", value: viewModel.promptTokenCountText)
                                labeledValue("Generated Tokens", value: viewModel.displayGeneratedTokens)
                                labeledValue("Total Tokens", value: viewModel.displayTotalTokens)
                            }
                        }
                    }

                    DSTitledSection(title: "Generation Settings") {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 24) {
                                Toggle(isOn: $viewModel.reasoningEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Enable Reasoning")
                                            .font(.headline)
                                        Text("Instructs the model to output its thinking inside <think>...</think> tags.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                                
                                Spacer()
                            }
                            
                            Divider()
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Max Generation Tokens:")
                                            .font(.headline)
                                        Text("\(viewModel.maxTokens)")
                                            .font(.body)
                                            .bold()
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: Binding(
                                        get: { Double(viewModel.maxTokens) },
                                        set: { viewModel.maxTokens = Int($0) }
                                    ), in: 256...32768, step: 256)
                                    .frame(maxWidth: .infinity)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Temperature:")
                                            .font(.headline)
                                        Text(String(format: "%.2f", viewModel.temperature))
                                            .font(.body)
                                            .bold()
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $viewModel.temperature, in: 0.0...1.5, step: 0.05)
                                    .frame(maxWidth: .infinity)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Top-P:")
                                            .font(.headline)
                                        Text(String(format: "%.2f", viewModel.topP))
                                            .font(.body)
                                            .bold()
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $viewModel.topP, in: 0.0...1.0, step: 0.05)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    if viewModel.isRunning {
                        DSTitledSection(title: "Progress") {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text(viewModel.runtimeState)
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        DSTitledSection(title: "Error") {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                    }

                    DSTitledSection(title: "Output") {
                        if viewModel.output.isEmpty {
                            Text("Start the runtime, warm or restore the cache, then select an image and run extraction.")
                                .foregroundStyle(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if viewModel.reasoningEnabled || !viewModel.thinkingOutput.isEmpty {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Thinking Process")
                                        .font(.headline)
                                        .foregroundStyle(.orange)
                                    
                                    if viewModel.thinkingOutput.isEmpty {
                                        Text("Thinking process is starting...")
                                            .foregroundStyle(.secondary)
                                            .italic()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                            .padding()
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .cornerRadius(8)
                                    } else {
                                        DSCodeBlock(viewModel.thinkingOutput)
                                            .frame(minHeight: 280)
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Final Extraction Output (XML)")
                                        .font(.headline)
                                        .foregroundStyle(.blue)
                                    
                                    if viewModel.finalOutput.isEmpty {
                                        Text("Waiting for final output...")
                                            .foregroundStyle(.secondary)
                                            .italic()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                            .padding()
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .cornerRadius(8)
                                    } else {
                                        DSCodeBlock(viewModel.finalOutput)
                                            .frame(minHeight: 280)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Final Extraction Output (XML)")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                
                                DSCodeBlock(viewModel.finalOutput)
                                    .frame(minHeight: 280)
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingImage,
            allowedContentTypes: allowedImageTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.selectImageResult(url)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func labeledValue(_ title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .bold()
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private var allowedImageTypes: [UTType] {
        var types: [UTType] = [.png, .jpeg, .heic, .image]
        if let webP = UTType(filenameExtension: "webp") {
            types.append(webP)
        }
        return types
    }

    // MARK: - Pipeline Phase Helpers

    private enum StepStatus {
        case pending, active, completed, failed
    }

    private var loadModelStatus: StepStatus {
        switch viewModel.executionPhase {
        case .unloaded: return .pending
        case .loadingModel: return .active
        case .failed:
            return viewModel.modelDetails?.modelType == nil ? .failed : .completed
        default: return .completed
        }
    }

    private var promptPrefillStatus: StepStatus {
        switch viewModel.executionPhase {
        case .unloaded, .loadingModel, .modelReady: return .pending
        case .processingPrompt: return .active
        case .decodingTokens, .complete: return .completed
        case .failed:
            return viewModel.executionPhase == .failed ? .failed : .pending
        }
    }

    private var generateOutputStatus: StepStatus {
        switch viewModel.executionPhase {
        case .unloaded, .loadingModel, .modelReady, .processingPrompt: return .pending
        case .decodingTokens: return .active
        case .complete: return .completed
        case .failed:
            return .failed
        }
    }

    private func stepView(title: String, status: StepStatus) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color(for: status).opacity(0.15))
                    .frame(width: 24, height: 24)
                
                if status == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color(for: status))
                } else if status == .active {
                    ProgressView()
                        .scaleEffect(0.5)
                } else if status == .failed {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color(for: status))
                } else {
                    Circle()
                        .strokeBorder(color(for: status), lineWidth: 2)
                        .frame(width: 10, height: 10)
                }
            }
            
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundStyle(status == .active ? .primary : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(status == .active ? color(for: status).opacity(0.1) : Color.clear)
        )
    }

    private func stepConnector(status: StepStatus) -> some View {
        Rectangle()
            .fill(status == .completed ? Color.green : Color.gray.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }

    private func color(for status: StepStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .active: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
