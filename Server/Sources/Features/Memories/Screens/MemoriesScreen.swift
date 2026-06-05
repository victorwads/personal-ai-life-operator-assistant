import SwiftUI

struct MemoriesScreen: View {
    let feature: MemoriesFeature

    @State private var memories: [Memory] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var loadErrorMessage: String?
    @State private var actionMessage: String?
    @State private var actionMessageStyle: ActionMessageStyle = .neutral
    @State private var draftKey = ""
    @State private var draftValue = ""
    @State private var editorMode: EditorMode = .inactive
    @State private var memoryPendingDeletion: Memory?
    @FocusState private var focusedField: DraftField?

    private enum DraftField {
        case key
        case value
    }

    private enum EditorMode: Equatable {
        case inactive
        case creating
        case editing(String)

        var isActive: Bool {
            switch self {
            case .inactive:
                return false
            case .creating, .editing:
                return true
            }
        }

        var editingID: String? {
            switch self {
            case .inactive, .creating:
                return nil
            case .editing(let id):
                return id
            }
        }
    }

    private enum ActionMessageStyle {
        case neutral
        case success
        case warning
        case danger

        var foregroundColor: Color {
            switch self {
            case .neutral:
                return .secondary
            case .success:
                return .green
            case .warning:
                return .orange
            case .danger:
                return .red
            }
        }
    }

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: "Memories",
                    subtitle: "Permanent assistant context saved for this profile."
                ) {
                    HStack(spacing: 12) {
                        Button {
                            startCreatingMemory()
                        } label: {
                            Label("New Memory", systemImage: "plus")
                        }

                        DSRefreshButton(isLoading: isLoading) {
                            loadMemories()
                        }
                    }
                }

                content
            }
        }
        .task {
            await refreshMemories()
        }
        .confirmationDialog(
            "Delete Memory",
            isPresented: Binding(
                get: { memoryPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        memoryPendingDeletion = nil
                    }
                }
            ),
            presenting: memoryPendingDeletion
        ) { memory in
            Button("Delete \(memory.key)", role: .destructive) {
                Task {
                    await delete(memory)
                }
            }
        } message: { memory in
            Text("This will permanently delete the memory \"\(memory.key)\".")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && memories.isEmpty {
            loadingState
        } else if let loadErrorMessage, memories.isEmpty {
            EmptyStateView(
                title: "Could not load memories",
                message: loadErrorMessage,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again",
                action: loadMemories
            )
        } else if memories.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if editorMode.isActive {
                        editorSection
                    }

                    memoriesSection
                }
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshMemories()
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let loadErrorMessage {
                        loadErrorBanner(message: loadErrorMessage)
                    }

                    memoriesSection
                    if editorMode.isActive {
                        editorSection
                    }
                }
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshMemories()
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading memories...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var editorSection: some View {
        let isEditing = editorMode.editingID != nil

        return DSTitledSection(
            title: isEditing ? "Edit Memory" : "Create Memory",
            subtitle: "Use the key as the durable lookup handle. Double-click a row to load it here.",
            systemImage: "square.and.pencil"
        ) {
            if let actionMessage {
                Text(actionMessage)
                    .font(.callout)
                    .foregroundStyle(actionMessageStyle.foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key")
                        .font(.subheadline.weight(.semibold))

                    TextField("client_language", text: $draftKey)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .key)
                        .onSubmit {
                            Task {
                                await saveDraft()
                            }
                        }

                    Text("Keep keys stable and descriptive so the assistant can reuse them reliably.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Value")
                        .font(.subheadline.weight(.semibold))

                    TextEditor(text: $draftValue)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .focused($focusedField, equals: .value)

                    Text("Use this for durable facts, preferences, and other permanent context.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await saveDraft()
                        }
                    } label: {
                        Label(isEditing ? "Save Changes" : "Create Memory", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSaveDraft || isSaving || isLoading)

                    if isEditing {
                        Button("Cancel Edit") {
                            startCreatingMemory()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSaving || isLoading)
                    }

                    Spacer(minLength: 0)

                    if isSaving {
                        ProgressView()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var memoriesSection: some View {
        DSTitledSection(
            title: "Saved Memories",
            subtitle: "Select a row to load it into the editor, then save or delete it from here.",
            systemImage: "brain.head.profile"
        ) {
            if memories.isEmpty {
                Text("No memories yet. Create the first one above.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(memories.indices, id: \.self) { index in
                        let memory = memories[index]
                        memoryRow(memory)
                    }
                }
            }
        }
    }

    private func memoryRow(_ memory: Memory) -> some View {
        DSListCardRow(
            title: memory.key,
            subtitle: memory.id.map { "ID: \($0.prefix(8))" },
            description: memory.value,
            systemImage: "brain"
        ) {
            HStack(spacing: 8) {
                if memory.id == editorMode.editingID {
                    DSBadge("Editing", style: .warning)
                }

                DSBadge("Value", secondaryText: valueSummary(for: memory), style: .info)
            }
        } trailing: {
            HStack(spacing: 8) {
                Button("Edit") {
                    startEditing(memory)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    memoryPendingDeletion = memory
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            startEditing(memory)
        }
    }

    private func loadErrorBanner(message: String) -> some View {
        DSCard(systemImage: "exclamationmark.triangle") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Could not refresh memories")
                        .font(.headline)

                    Text(message)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("Try Again") {
                    loadMemories()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func loadMemories() {
        Task {
            await refreshMemories()
        }
    }

    @MainActor
    private func refreshMemories() async {
        isLoading = true
        loadErrorMessage = nil

        do {
            let loadedMemories = try await feature.repository.getAll()
            memories = sortedMemories(loadedMemories)

            if let editingMemoryID = editorMode.editingID,
               !memories.contains(where: { $0.id == editingMemoryID }) {
                editorMode = .inactive
                draftKey = ""
                draftValue = ""
                actionMessage = nil
                actionMessageStyle = .neutral
            }
        } catch {
            loadErrorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private var canSaveDraft: Bool {
        !draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !draftValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startCreatingMemory() {
        editorMode = .creating
        draftKey = ""
        draftValue = ""
        actionMessage = nil
        actionMessageStyle = .neutral
        focusedField = .key
    }

    private func startEditing(_ memory: Memory) {
        guard let memoryID = memory.id, !memoryID.isEmpty else {
            return
        }

        editorMode = .editing(memoryID)
        draftKey = memory.key
        draftValue = memory.value
        actionMessage = nil
        actionMessageStyle = .neutral
        focusedField = .key
    }

    @MainActor
    private func saveDraft() async {
        let trimmedKey = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = draftValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            showActionMessage("The key cannot be empty.", style: .warning)
            focusedField = .key
            return
        }

        guard !trimmedValue.isEmpty else {
            showActionMessage("The value cannot be empty.", style: .warning)
            focusedField = .value
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let matchingMemory = try await feature.repository.query(
                matching: ["key": trimmedKey],
                limit: 1
            ).first

            let targetID: String?
            if let editingMemoryID = editorMode.editingID {
                if let matchingMemory, let matchingID = matchingMemory.id, matchingID != editingMemoryID {
                    showActionMessage("Another memory already uses that key.", style: .danger)
                    return
                }
                targetID = editingMemoryID
            } else {
                targetID = matchingMemory?.id
            }

            if let targetID {
                try await feature.repository.update(
                    id: targetID,
                    data: [
                        "key": trimmedKey,
                        "value": trimmedValue
                    ]
                )
                editorMode = .editing(targetID)
                showActionMessage("Memory saved.", style: .success)
            } else {
                let savedMemory = try await feature.repository.save(
                    Memory(id: nil, key: trimmedKey, value: trimmedValue)
                )
                if let savedMemoryID = savedMemory.id, !savedMemoryID.isEmpty {
                    editorMode = .editing(savedMemoryID)
                } else {
                    editorMode = .inactive
                }
                showActionMessage("Memory created.", style: .success)
            }

            draftKey = trimmedKey
            draftValue = trimmedValue
            await refreshMemories()
        } catch {
            showActionMessage(error.localizedDescription, style: .danger)
        }
    }

    private func showActionMessage(_ message: String, style: ActionMessageStyle) {
        actionMessage = message
        actionMessageStyle = style
    }

    private func valueSummary(for memory: Memory) -> String {
        let compactValue = memory.value.replacingOccurrences(of: "\n", with: " ")
        if compactValue.count <= 24 {
            return compactValue
        }
        return String(compactValue.prefix(24)) + "…"
    }

    private func sortedMemories(_ memories: [Memory]) -> [Memory] {
        memories.sorted { lhs, rhs in
            switch lhs.key.localizedCaseInsensitiveCompare(rhs.key) {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                return lhs.value.localizedCaseInsensitiveCompare(rhs.value) == .orderedAscending
            }
        }
    }

    @MainActor
    private func delete(_ memory: Memory) async {
        guard !isDeleting else {
            return
        }

        isDeleting = true
        defer {
            isDeleting = false
            memoryPendingDeletion = nil
        }

        do {
            if let memoryID = memory.id {
                try await feature.repository.delete(memoryID)
            } else if let memoryID = try await feature.repository.query(
                matching: ["key": memory.key],
                limit: 1
            ).first?.id {
                try await feature.repository.delete(memoryID)
            } else {
                throw NSError(domain: "MemoriesScreen", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find the memory to delete."
                ])
            }

            if editorMode.editingID == memory.id {
                editorMode = .inactive
                draftKey = ""
                draftValue = ""
                actionMessage = nil
                actionMessageStyle = .neutral
            }

            showActionMessage("Memory deleted.", style: .success)
            await refreshMemories()
        } catch {
            showActionMessage(error.localizedDescription, style: .danger)
        }
    }
}
