import SwiftUI

struct AIRuntimeScreen: View {
    private let runtime: AIRuntime
    private let settings: AIRuntimeSettingsWrapper

    init(feature: AIRuntimeFeature) {
        self.runtime = feature.runtime
        self.settings = feature.settings
    }

    var body: some View {
        AIRuntimePoCScreen(runtime: runtime, settings: settings)
    }
}
