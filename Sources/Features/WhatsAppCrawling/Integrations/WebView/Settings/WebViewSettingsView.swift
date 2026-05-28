import SwiftUI

struct WhatsAppWebViewSettingsView: View {
    let wrapper: WhatsAppWebViewSettingsWrapper

    @State private var url = ""
    @State private var userAgent = ""
    @State private var zoom = 1.0
    @State private var viewportWidth = 1280
    @State private var viewportHeight = 720
    @State private var enableWebInspector = true
    @State private var websiteDataStoreIdentifier = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("URL", text: urlBinding)
            TextField("User Agent", text: userAgentBinding)

            Stepper("Zoom: \(zoom, specifier: "%.1f")", value: zoomBinding, in: 0.5...3.0, step: 0.1)
            Stepper("Viewport Width: \(viewportWidth)", value: viewportWidthBinding, in: 320...3840)
            Stepper("Viewport Height: \(viewportHeight)", value: viewportHeightBinding, in: 240...2160)
            Toggle("Enable Web Inspector", isOn: enableWebInspectorBinding)

            LabeledContent("Data Store") {
                Text(websiteDataStoreIdentifier.isEmpty ? "Generated on first start" : websiteDataStoreIdentifier)
                    .textSelection(.enabled)
            }
        }
        .task {
            load()
        }
    }

    private var zoomBinding: Binding<Double> {
        Binding {
            zoom
        } set: { value in
            zoom = value
            wrapper.zoom = value
        }
    }

    private var urlBinding: Binding<String> {
        Binding {
            url
        } set: { value in
            url = value
            wrapper.url = value
        }
    }

    private var userAgentBinding: Binding<String> {
        Binding {
            userAgent
        } set: { value in
            userAgent = value
            wrapper.userAgent = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        }
    }

    private var viewportWidthBinding: Binding<Int> {
        Binding {
            viewportWidth
        } set: { value in
            viewportWidth = value
            wrapper.viewportWidth = value
        }
    }

    private var viewportHeightBinding: Binding<Int> {
        Binding {
            viewportHeight
        } set: { value in
            viewportHeight = value
            wrapper.viewportHeight = value
        }
    }

    private var enableWebInspectorBinding: Binding<Bool> {
        Binding {
            enableWebInspector
        } set: { value in
            enableWebInspector = value
            wrapper.enableWebInspector = value
        }
    }

    private func load() {
        url = wrapper.url
        userAgent = wrapper.userAgent ?? ""
        zoom = wrapper.zoom
        viewportWidth = wrapper.viewportWidth
        viewportHeight = wrapper.viewportHeight
        enableWebInspector = wrapper.enableWebInspector
        websiteDataStoreIdentifier = wrapper.websiteDataStoreIdentifier
    }
}
