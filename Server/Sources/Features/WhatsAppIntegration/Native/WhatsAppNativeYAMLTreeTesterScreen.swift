import SwiftUI

struct WhatsAppNativeYAMLTreeTesterScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var model = WhatsAppNativeYAMLTreeTesterViewModel()

    var body: some View {
        HSplitView {
            leftPane
                .frame(minWidth: 420, idealWidth: 560, maxWidth: .infinity, maxHeight: .infinity)

            rightPane
                .frame(minWidth: 420, idealWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await model.loadBundledYAMLIfNeeded() }
        .onChange(of: model.yamlText) { _, _ in
            model.reparseYAML()
        }
    }

    private var leftPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("YAML (in-memory)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task { await model.loadBundledYAML(force: true) }
                } label: {
                    Label("Reload bundled", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)

                Button {
                    Task { await runTest() }
                } label: {
                    Label("Test", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.isRunning)

                Button {
                    model.clearExecutionResults()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .controlSize(.small)
                .disabled(model.executionRoot == nil)
            }
            .padding(12)

            Divider()

            TextEditor(text: $model.yamlText)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var rightPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("YAML Tree")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    model.clearExecutionResults()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .controlSize(.small)
                .disabled(model.executionRoot == nil)

                Button {
                    model.requestExpandAll()
                } label: {
                    Label("Expand All", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .controlSize(.small)
                .disabled(model.structureRoot == nil)

                Button {
                    model.requestCollapseAll()
                } label: {
                    Label("Collapse All", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .controlSize(.small)
                .disabled(model.structureRoot == nil)

                if model.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)

            Divider()

            YAMLTreeBrowserView(
                structureRoot: model.structureRoot,
                executionRoot: model.executionRoot,
                parseError: model.parseError,
                expansionState: model.expansionState
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @MainActor
    private func runTest() async {
        await model.runTest(accessibility: appModel.accessibility)
    }
}

@MainActor
final class WhatsAppNativeYAMLTreeTesterViewModel: ObservableObject {
    @Published var yamlText: String = ""
    @Published var isRunning = false
    @Published var parseError: String?
    @Published var structureRoot: YAMLStructureNode?
    @Published var executionRoot: YAMLExecutionNode?

    let expansionState = YAMLTreeExpansionState()

    private var didLoadBundled = false
    private let runner = WhatsAppNativeYAMLExtractionRunner()

    func loadBundledYAMLIfNeeded() async {
        guard !didLoadBundled else { return }
        didLoadBundled = true
        await loadBundledYAML(force: true)
    }

    func loadBundledYAML(force: Bool) async {
        guard force || yamlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "whatsapp_native_selectors", withExtension: "yaml"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            parseError = "Could not load bundled YAML resource `whatsapp_native_selectors.yaml`."
            return
        }

        yamlText = text
        reparseYAML()
    }

    func reparseYAML() {
        do {
            let tree = try YAMLTree.parse(yaml: yamlText)
            structureRoot = YAMLStructureNode.from(any: .object(tree.root), title: "root", path: "root")
            parseError = nil
        } catch {
            structureRoot = nil
            parseError = error.localizedDescription
        }
    }

    func runTest(accessibility: AccessibilityService) async {
        isRunning = true
        defer { isRunning = false }
        executionRoot = nil

        do {
            let tree = try YAMLTree.parse(yaml: yamlText)
            let snapshot = try accessibility.captureWhatsAppSnapshot(maxDepth: 14)
            let result = try runner.run(yamlTree: tree, snapshotRoot: snapshot.rootNode)
            executionRoot = YAMLExecutionNode.from(any: result.tree, title: "root", path: "root")
        } catch {
            parseError = error.localizedDescription
        }
    }

    func clearExecutionResults() {
        executionRoot = nil
    }

    func requestExpandAll() {
        expansionState.requestExpandAll()
    }

    func requestCollapseAll() {
        expansionState.requestCollapseAll()
    }
}
