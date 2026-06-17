import SwiftUI

struct AIConnectionSettingsView: View {
    let wrapper: AIConnectionSettingsWrapper

    @State private var autoStart = false
    @State private var assistantProvider = AIProviderSettings(
        providerKind: .openRouter,
        baseURL: "",
        apiKey: "",
        model: "",
        reasoningEffort: .omit,
        cacheMode: .automatic
    )
    @State private var assistantRuntime = AIRuntimeGenerationSettings.defaultSettings

    @State private var imageProvider = AIProviderSettings(
        providerKind: .openRouter,
        baseURL: "",
        apiKey: "",
        model: "",
        reasoningEffort: .omit,
        cacheMode: .automatic
    )
    @State private var imageRuntime = AIRuntimeGenerationSettings.defaultSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Auto Start AI Connection", isOn: autoStartBinding)

            // Assistant Section
            GroupBox("Assistant Provider") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Provider", selection: assistantProviderKindBinding) {
                        ForEach(AIConnectionProviderKind.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    if assistantProvider.providerKind == .aiRuntime {
                        DSLocalAIRuntimeSettingsView(settings: assistantRuntimeBinding)
                    } else {
                        DSAIProviderSettingsView(settings: assistantProviderBinding)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if assistantProvider.providerKind != .aiRuntime {
                Stepper(
                    "Temperature: \(assistantRuntime.temperature, specifier: "%.1f")",
                    value: assistantTemperatureBinding,
                    in: 0...2,
                    step: 0.1
                )
                TextField("Max Output Tokens (optional)", text: assistantMaxTokensBinding)
                    .autocorrectionDisabled()
            }

            // Image Extraction Section
            GroupBox("Image Extraction Provider") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Provider", selection: imageProviderKindBinding) {
                        ForEach(AIConnectionProviderKind.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    if imageProvider.providerKind == .aiRuntime {
                        DSLocalAIRuntimeSettingsView(settings: imageRuntimeBinding)
                    } else {
                        DSAIProviderSettingsView(settings: imageProviderBinding)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Streaming is always used. Cache behavior depends on the selected provider.")
                .foregroundStyle(.secondary)
        }
        .task {
            load()
        }
    }

    private var autoStartBinding: Binding<Bool> {
        Binding {
            autoStart
        } set: { value in
            autoStart = value
            wrapper.autoStart = value
        }
    }

    private var assistantProviderKindBinding: Binding<AIConnectionProviderKind> {
        Binding {
            assistantProvider.providerKind
        } set: { value in
            assistantProvider.providerKind = value
            wrapper.saveProviderSettings(assistantProvider, for: .assistant)
            // Refresh settings from wrapper to handle defaults correctly
            assistantProvider = wrapper.loadProviderSettings(for: .assistant)
        }
    }

    private var assistantProviderBinding: Binding<AIProviderSettings> {
        Binding {
            assistantProvider
        } set: { value in
            assistantProvider = value
            wrapper.saveProviderSettings(value, for: .assistant)
        }
    }

    private var assistantRuntimeBinding: Binding<AIRuntimeGenerationSettings> {
        Binding {
            assistantRuntime
        } set: { value in
            assistantRuntime = value
            wrapper.saveRuntimeSettings(value, for: .assistant)
        }
    }

    private var assistantTemperatureBinding: Binding<Double> {
        Binding {
            assistantRuntime.temperature
        } set: { value in
            assistantRuntime.temperature = value
            wrapper.saveRuntimeSettings(assistantRuntime, for: .assistant)
        }
    }

    private var assistantMaxTokensBinding: Binding<String> {
        Binding {
            assistantRuntime.maxTokens > 0 ? String(assistantRuntime.maxTokens) : ""
        } set: { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let intVal = Int(trimmed), intVal > 0 {
                assistantRuntime.maxTokens = intVal
            } else {
                assistantRuntime.maxTokens = 0
            }
            wrapper.saveRuntimeSettings(assistantRuntime, for: .assistant)
        }
    }

    private var imageProviderKindBinding: Binding<AIConnectionProviderKind> {
        Binding {
            imageProvider.providerKind
        } set: { value in
            imageProvider.providerKind = value
            wrapper.saveProviderSettings(imageProvider, for: .imageExtraction)
            // Refresh settings from wrapper to handle defaults correctly
            imageProvider = wrapper.loadProviderSettings(for: .imageExtraction)
        }
    }

    private var imageProviderBinding: Binding<AIProviderSettings> {
        Binding {
            imageProvider
        } set: { value in
            imageProvider = value
            wrapper.saveProviderSettings(value, for: .imageExtraction)
        }
    }

    private var imageRuntimeBinding: Binding<AIRuntimeGenerationSettings> {
        Binding {
            imageRuntime
        } set: { value in
            imageRuntime = value
            wrapper.saveRuntimeSettings(value, for: .imageExtraction)
        }
    }

    private func load() {
        autoStart = wrapper.autoStart
        assistantProvider = wrapper.loadProviderSettings(for: .assistant)
        assistantRuntime = wrapper.loadRuntimeSettings(for: .assistant)
        imageProvider = wrapper.loadProviderSettings(for: .imageExtraction)
        imageRuntime = wrapper.loadRuntimeSettings(for: .imageExtraction)
    }
}
