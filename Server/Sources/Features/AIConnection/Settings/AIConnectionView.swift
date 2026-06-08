import SwiftUI

struct AIConnectionSettingsView: View {
    let wrapper: AIConnectionSettingsWrapper

    @State private var autoStart = false
    @State private var assistantProviderKind = AIConnectionProviderKind.openRouter
    @State private var assistantBaseURL = ""
    @State private var assistantAPIKey = ""
    @State private var assistantModel = ""
    @State private var temperature = 0.6
    @State private var reasoningEffort = AIConnectionReasoningEffort.off
    @State private var maxOutputTokens = ""
    @State private var assistantCacheMode = AIConnectionCacheMode.automatic
    @State private var imageProviderKind = AIConnectionProviderKind.openRouter
    @State private var imageBaseURL = ""
    @State private var imageAPIKey = ""
    @State private var imageModel = ""
    @State private var imageCacheMode = AIConnectionCacheMode.automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Auto Start AI Connection", isOn: autoStartBinding)
            providerSection(
                title: "Assistant Provider",
                providerKind: assistantProviderKindBinding,
                baseURL: assistantBaseURLBinding,
                apiKey: assistantAPIKeyBinding,
                model: assistantModelBinding,
                cacheMode: assistantCacheModeBinding
            )
            Stepper(
                "Temperature: \(temperature, specifier: "%.1f")",
                value: temperatureBinding,
                in: 0...2,
                step: 0.1
            )
            Picker("Reasoning", selection: reasoningEffortBinding) {
                ForEach(AIConnectionReasoningEffort.allCases, id: \.self) { effort in
                    Text(effort.displayName).tag(effort)
                }
            }
            TextField("Max Output Tokens (optional)", text: maxOutputTokensBinding)
                .autocorrectionDisabled()
            providerSection(
                title: "Image Extraction Provider",
                providerKind: imageProviderKindBinding,
                baseURL: imageBaseURLBinding,
                apiKey: imageAPIKeyBinding,
                model: imageModelBinding,
                cacheMode: imageCacheModeBinding
            )

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
            assistantProviderKind
        } set: { value in
            assistantProviderKind = value
            wrapper.providerKind = value
            assistantBaseURL = wrapper.baseURL
        }
    }

    private var assistantBaseURLBinding: Binding<String> {
        Binding {
            assistantBaseURL
        } set: { value in
            assistantBaseURL = value
            wrapper.baseURL = value
        }
    }

    private var assistantAPIKeyBinding: Binding<String> {
        Binding {
            assistantAPIKey
        } set: { value in
            assistantAPIKey = value
            wrapper.apiKey = value
        }
    }

    private var assistantModelBinding: Binding<String> {
        Binding {
            assistantModel
        } set: { value in
            assistantModel = value
            wrapper.model = value
        }
    }

    private var temperatureBinding: Binding<Double> {
        Binding {
            temperature
        } set: { value in
            let normalizedValue = min(max(value, 0), 2)
            temperature = normalizedValue
            wrapper.temperature = normalizedValue
        }
    }

    private var reasoningEffortBinding: Binding<AIConnectionReasoningEffort> {
        Binding {
            reasoningEffort
        } set: { value in
            reasoningEffort = value
            wrapper.reasoningEffort = value
        }
    }

    private var maxOutputTokensBinding: Binding<String> {
        Binding {
            maxOutputTokens
        } set: { value in
            maxOutputTokens = value
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            wrapper.maxOutputTokens = Int(trimmedValue)
        }
    }

    private var assistantCacheModeBinding: Binding<AIConnectionCacheMode> {
        Binding {
            assistantCacheMode
        } set: { value in
            assistantCacheMode = value
            wrapper.cacheMode = value
        }
    }

    private var imageProviderKindBinding: Binding<AIConnectionProviderKind> {
        Binding {
            imageProviderKind
        } set: { value in
            imageProviderKind = value
            wrapper.imageExtractionProviderKind = value
            imageBaseURL = wrapper.imageExtractionBaseURL
        }
    }

    private var imageBaseURLBinding: Binding<String> {
        Binding {
            imageBaseURL
        } set: { value in
            imageBaseURL = value
            wrapper.imageExtractionBaseURL = value
        }
    }

    private var imageAPIKeyBinding: Binding<String> {
        Binding {
            imageAPIKey
        } set: { value in
            imageAPIKey = value
            wrapper.imageExtractionAPIKey = value
        }
    }

    private var imageModelBinding: Binding<String> {
        Binding {
            imageModel
        } set: { value in
            imageModel = value
            wrapper.imageExtractionModel = value
        }
    }

    private var imageCacheModeBinding: Binding<AIConnectionCacheMode> {
        Binding {
            imageCacheMode
        } set: { value in
            imageCacheMode = value
            wrapper.imageExtractionCacheMode = value
        }
    }

    private func load() {
        autoStart = wrapper.autoStart
        assistantProviderKind = wrapper.providerKind
        assistantBaseURL = wrapper.baseURL
        assistantAPIKey = wrapper.apiKey
        assistantModel = wrapper.model
        temperature = wrapper.temperature
        reasoningEffort = wrapper.reasoningEffort
        maxOutputTokens = wrapper.maxOutputTokens.map(String.init) ?? ""
        assistantCacheMode = wrapper.cacheMode
        imageProviderKind = wrapper.imageExtractionProviderKind
        imageBaseURL = wrapper.imageExtractionBaseURL
        imageAPIKey = wrapper.imageExtractionAPIKey
        imageModel = wrapper.imageExtractionModel
        imageCacheMode = wrapper.imageExtractionCacheMode
    }

    @ViewBuilder
    private func providerSection(
        title: String,
        providerKind: Binding<AIConnectionProviderKind>,
        baseURL: Binding<String>,
        apiKey: Binding<String>,
        model: Binding<String>,
        cacheMode: Binding<AIConnectionCacheMode>
    ) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Provider", selection: providerKind) {
                    ForEach(AIConnectionProviderKind.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                TextField("Base URL", text: baseURL)
                    .autocorrectionDisabled()
                SecureField("API Key", text: apiKey)
                TextField("Model", text: model)
                    .autocorrectionDisabled()
                Picker("Cache Mode", selection: cacheMode) {
                    ForEach(AIConnectionCacheMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
