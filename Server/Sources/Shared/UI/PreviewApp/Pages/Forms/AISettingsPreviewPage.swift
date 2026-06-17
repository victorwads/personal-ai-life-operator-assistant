import SwiftUI

struct AISettingsPreviewPage: View {
    @State private var providerSettings = AIProviderSettings(
        providerKind: .openRouter,
        baseURL: "https://openrouter.ai/api/v1",
        apiKey: "sk-or-...",
        model: "meta-llama/llama-3-70b-instruct",
        reasoningEffort: .omit,
        cacheMode: .automatic
    )

    @State private var runtimeSettings = AIRuntimeGenerationSettings.defaultSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("AI Settings Views Preview")
                    .font(.title)
                    .bold()

                GroupBox("DSAIProviderSettingsView") {
                    DSAIProviderSettingsView(settings: $providerSettings)
                        .padding()
                }

                GroupBox("DSLocalAIRuntimeSettingsView") {
                    DSLocalAIRuntimeSettingsView(settings: $runtimeSettings)
                        .padding()
                }
            }
            .padding()
        }
    }
}
