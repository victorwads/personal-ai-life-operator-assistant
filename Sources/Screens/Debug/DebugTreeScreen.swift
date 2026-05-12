import AppKit
import SwiftUI

struct DebugTreeScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedChildIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if let snapshot = appModel.debugSnapshot {
                let currentNode = snapshot.rootNode.node(at: appModel.debugNodePath) ?? snapshot.rootNode

                VStack(alignment: .leading, spacing: 12) {
                    nodeSummary(currentNode, title: "Current Node")
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

                    Divider()

                    HSplitView {
                        List(selection: $selectedChildIndex) {
                            ForEach(Array(currentNode.children.enumerated()), id: \.offset) { index, child in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rowTitle(for: child, index: index))
                                        .font(.system(.caption, design: .monospaced))
                                    Text(rowSubtitle(for: child))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                                .tag(Optional(index))
                                .onTapGesture(count: 2) {
                                    appModel.debugNodePath.append(index)
                                    selectedChildIndex = nil
                                }
                            }
                        }
                        .frame(minWidth: 420)

                        VStack(alignment: .leading, spacing: 10) {
                            if let selectedChildIndex,
                               currentNode.children.indices.contains(selectedChildIndex) {
                                nodeSummary(currentNode.children[selectedChildIndex], title: "Selected Child")
                            } else {
                                ContentUnavailableView(
                                    "Select a node",
                                    systemImage: "cursorarrow.click",
                                    description: Text("Click an item to see its details, or double-click to navigate into it.")
                                )
                            }
                        }
                        .padding(12)
                        .frame(minWidth: 360)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No snapshot loaded",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Press Capture to load the current WhatsApp accessibility tree.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Debug Tree")
                .font(.title3.weight(.semibold))

            Spacer()

            Button {
                appModel.captureDebugSnapshot()
            } label: {
                Label("Capture", systemImage: "camera")
            }

            Button {
                guard !appModel.debugNodePath.isEmpty else { return }
                appModel.debugNodePath.removeLast()
                selectedChildIndex = nil
            } label: {
                Label("Up", systemImage: "arrow.up")
            }
            .disabled(appModel.debugNodePath.isEmpty)

            Button {
                copyToPasteboard(appModel.debugNodePath.map(String.init).joined(separator: "."))
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            .disabled(appModel.debugSnapshot == nil)
        }
        .padding(12)
    }

    private func nodeSummary(_ node: RawAXNode, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("path=\(node.accessibilityPath.map(String.init).joined(separator: "."))  role=\(node.role ?? "nil")  subrole=\(node.subrole ?? "nil")")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)

            let text = node.ownTextFragments
                .map { $0.normalizedAXText }
                .filter { !$0.isEmpty }
                .joined(separator: " | ")

            if !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            if let frame = node.frame {
                Text("frame x:\(Int(frame.minX)) y:\(Int(frame.minY)) w:\(Int(frame.width)) h:\(Int(frame.height))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowTitle(for node: RawAXNode, index: Int) -> String {
        let role = node.role ?? "nil"
        let pathSuffix = "\(index)"
        return "\(pathSuffix)  \(role)"
    }

    private func rowSubtitle(for node: RawAXNode) -> String {
        let text = node.ownTextFragments
            .map { $0.normalizedAXText }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " | ")
        return text.isEmpty ? "—" : text
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

