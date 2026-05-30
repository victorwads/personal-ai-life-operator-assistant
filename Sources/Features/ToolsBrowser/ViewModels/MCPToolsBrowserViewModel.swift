import Foundation

@MainActor
final class MCPToolsBrowserViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var selectedGroup: String?
    @Published var selectedToolName: String? {
        didSet {
            guard selectedToolName != oldValue else { return }
            resetArgumentsFromSelectedToolExamples()
        }
    }
    @Published var argumentDrafts: [String: MCPJSONValue] = [:]
    @Published var executionState: MCPToolExecutionState = .idle

    private let mcpServersFeature: MCPServersFeature
    private let tools: [any MCPToolDefinition]

    init(mcpServersFeature: MCPServersFeature) {
        self.mcpServersFeature = mcpServersFeature
        self.tools = mcpServersFeature.listToolDefinitions().sorted { lhs, rhs in
            if lhs.group == rhs.group {
                return lhs.name < rhs.name
            }
            return lhs.group < rhs.group
        }
        self.selectedToolName = tools.first?.name
        resetArgumentsFromSelectedToolExamples()
    }

    var allEntries: [MCPToolBrowserEntry] {
        tools.map { MCPToolBrowserEntry(tool: $0) }
    }

    var filteredEntries: [MCPToolBrowserEntry] {
        allEntries.filter { entry in
            let matchesGroup = selectedGroup == nil || entry.group == selectedGroup
            let matchesSearch = searchQuery
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty || entry.matches(searchQuery)

            return matchesGroup && matchesSearch
        }
    }

    var groups: [String] {
        Array(Set(tools.map(\.group))).sorted()
    }

    var selectedTool: (any MCPToolDefinition)? {
        guard let selectedToolName else { return nil }
        return tools.first { $0.name == selectedToolName }
    }

    var selectedToolExamples: [MCPToolExampleParameter] {
        selectedTool?.exampleParameters ?? []
    }

    var payloadPreview: String {
        guard let selectedTool else { return "" }
        return MCPToolsBrowserJSONFormatting.prettyPrinted(
            call: MCPToolCall(name: selectedTool.name, arguments: argumentDrafts)
        )
    }

    var hasTools: Bool {
        !tools.isEmpty
    }

    func selectTool(named name: String) {
        selectedToolName = name
    }

    func resetArgumentsFromSelectedToolExamples() {
        guard let selectedTool else {
            argumentDrafts = [:]
            executionState = .idle
            return
        }

        argumentDrafts = Dictionary(
            uniqueKeysWithValues: selectedTool.exampleParameters.map { ($0.name, $0.value) }
        )
        executionState = .idle
    }

    func runSelectedTool() async {
        guard let selectedTool else { return }

        executionState = .running
        let call = MCPToolCall(name: selectedTool.name, arguments: argumentDrafts)
        let result = await mcpServersFeature.executeToolCall(call)
        executionState = result.success ? .success(result) : .failure(result)
    }
}

private extension MCPToolBrowserEntry {
    func matches(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return true }

        return name.localizedCaseInsensitiveContains(normalizedQuery)
            || description.localizedCaseInsensitiveContains(normalizedQuery)
            || group.localizedCaseInsensitiveContains(normalizedQuery)
    }
}
