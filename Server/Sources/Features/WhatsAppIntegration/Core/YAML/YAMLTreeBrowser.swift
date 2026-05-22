import SwiftUI

struct YAMLTreeBrowserView: View {
    @State private var selectedPath: String?

    let structureRoot: YAMLStructureNode?
    let executionRoot: YAMLExecutionNode?
    let parseError: String?
    let expansionState: YAMLTreeExpansionState

    var body: some View {
        HStack(spacing: 0) {
            structureColumn
                .frame(minWidth: 360, idealWidth: 430, maxWidth: 520, maxHeight: .infinity)

            Divider()

            detailColumn
                .frame(minWidth: 320, idealWidth: 430, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selectedPath == nil {
                selectedPath = structureRoot?.children?.first?.path
            }
        }
        .onChange(of: expansionState.revision) { _, _ in
            if selectedPath == nil {
                selectedPath = structureRoot?.children?.first?.path
            }
        }
    }

    private var structureColumn: some View {
        Group {
            if let structureRoot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        YAMLTreeNodeView(
                            node: structureRoot,
                            executionRoot: executionRoot,
                            expansionState: expansionState,
                            selectedPath: $selectedPath,
                            isRoot: true
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No YAML structure")
                        .font(.headline)
                    Text(parseError ?? "Load or fix the YAML to see the tree.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.02))
    }

    private var detailColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let parseError, !parseError.isEmpty {
                    Text(parseError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                if let executionRoot, let executedNode = executionRoot.find(path: selectedPath), structureRoot?.find(path: selectedPath) == nil {
                    Text(executedNode.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text("Test Result")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(executedNode.summaryText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else if let structureRoot, let selectedNode = structureRoot.find(path: selectedPath) {
                    Text(selectedNode.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(selectedNode.summaryText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    if let executionRoot, let executedNode = executionRoot.find(path: selectedNode.path) {
                        Divider().padding(.vertical, 4)
                        Text("Test Result")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(executedNode.summaryText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Divider().padding(.vertical, 4)
                        Text("Press Test to run this tree against the current integration snapshot.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Select a node to inspect its YAML and execution result.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.01))
    }
}

private struct YAMLTreeNodeView: View {
    let node: YAMLStructureNode
    let executionRoot: YAMLExecutionNode?
    let expansionState: YAMLTreeExpansionState
    @Binding var selectedPath: String?
    let isRoot: Bool

    @State private var isExpanded: Bool

    init(
        node: YAMLStructureNode,
        executionRoot: YAMLExecutionNode?,
        expansionState: YAMLTreeExpansionState,
        selectedPath: Binding<String?>,
        isRoot: Bool = false
    ) {
        self.node = node
        self.executionRoot = executionRoot
        self.expansionState = expansionState
        self._selectedPath = selectedPath
        self.isRoot = isRoot
        self._isExpanded = State(initialValue: isRoot)
    }

    var body: some View {
        if let children = effectiveChildren, !children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(children) { child in
                        switch child {
                        case .structure(let structure):
                            YAMLTreeNodeView(
                                node: structure,
                                executionRoot: executionRoot,
                                expansionState: expansionState,
                                selectedPath: $selectedPath
                            )
                        case .execution(let execution):
                            YAMLExecutionTreeNodeView(
                                node: execution,
                                expansionState: expansionState,
                                selectedPath: $selectedPath
                            )
                        }
                    }
                }
                .padding(.leading, 14)
            } label: {
                row
            }
            .onChange(of: expansionState.revision) { _, _ in
                applyGlobalExpansionState()
            }
            .onAppear {
                applyGlobalExpansionState()
            }
        } else {
            row
        }
    }

    private enum EffectiveChild: Identifiable {
        case structure(YAMLStructureNode)
        case execution(YAMLExecutionNode)

        var id: String {
            switch self {
            case .structure(let node): return "s:\(node.id)"
            case .execution(let node): return "e:\(node.id)"
            }
        }
    }

    private var effectiveChildren: [EffectiveChild]? {
        if node.specType == "elements",
           let execNode = executionRoot?.find(path: node.path),
           let items = execNode.itemsChildren,
           !items.isEmpty
        {
            return items.map { .execution($0) }
        }

        guard let children = node.children, !children.isEmpty else { return nil }
        return children.map { .structure($0) }
    }

    private func applyGlobalExpansionState() {
        switch expansionState.mode {
        case .preserveExisting:
            if isRoot { isExpanded = true }
        case .expandAll:
            isExpanded = true
        case .collapseAll:
            isExpanded = false
        }
    }

    private var row: some View {
        let executionNode = executionRoot?.find(path: node.path)
        let isSelected = selectedPath == node.path
        let canExpand = (effectiveChildren?.isEmpty == false)

        return HStack(spacing: 8) {
            if let executionNode {
                if executionNode.isFound {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if executionNode.hasExplicitMiss {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: node.kind == .scalar ? "doc.text" : "circle.dashed")
                    .foregroundStyle(.secondary)
            }

            Text(node.title)
                .lineLimit(1)

            if let summary = node.inlineSummary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let executionNode, let badge = executionNode.badge, !badge.isEmpty {
                Text(badge)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture {
            selectedPath = node.path
        }
        .onTapGesture(count: 2) {
            guard canExpand else { return }
            isExpanded.toggle()
        }
    }
}

private struct YAMLExecutionTreeNodeView: View {
    let node: YAMLExecutionNode
    let expansionState: YAMLTreeExpansionState
    @Binding var selectedPath: String?

    @State private var isExpanded: Bool = false

    var body: some View {
        if let children = node.children, !children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(children) { child in
                        YAMLExecutionTreeNodeView(
                            node: child,
                            expansionState: expansionState,
                            selectedPath: $selectedPath
                        )
                    }
                }
                .padding(.leading, 14)
            } label: {
                row
            }
            .onChange(of: expansionState.revision) { _, _ in
                applyGlobalExpansionState()
            }
            .onAppear {
                applyGlobalExpansionState()
            }
        } else {
            row
        }
    }

    private func applyGlobalExpansionState() {
        switch expansionState.mode {
        case .preserveExisting:
            break
        case .expandAll:
            isExpanded = true
        case .collapseAll:
            isExpanded = false
        }
    }

    private var row: some View {
        let isSelected = selectedPath == node.path

        return HStack(spacing: 8) {
            if node.isFound {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if node.hasExplicitMiss {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            } else {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
            }

            Text(node.title)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let badge = node.badge, !badge.isEmpty {
                Text(badge)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture {
            selectedPath = node.path
        }
        .onTapGesture(count: 2) {
            if node.children?.isEmpty == false {
                isExpanded.toggle()
            }
        }
    }
}

