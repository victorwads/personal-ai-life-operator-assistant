import SwiftUI

struct MCPToolArgumentsEditor: View {
    let examples: [MCPToolExampleParameter]
    @Binding var argumentDrafts: [String: MCPJSONValue]

    var body: some View {
        MCPToolSectionCard(title: "Arguments") {
            if examples.isEmpty {
                Text("No editable example arguments are available for this tool.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(examples, id: \.name) { example in
                        argumentRow(for: example)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func argumentRow(for example: MCPToolExampleParameter) -> some View {
        let value = argumentDrafts[example.name] ?? example.value

        VStack(alignment: .leading, spacing: 6) {
            Text(example.name)
                .font(.subheadline.weight(.semibold))

            switch value {
            case .bool:
                Toggle("", isOn: boolBinding(for: example.name))
                    .labelsHidden()
            case .int:
                TextField("Value", text: intBinding(for: example.name))
                    .textFieldStyle(.roundedBorder)
            case .double:
                TextField("Value", text: doubleBinding(for: example.name))
                    .textFieldStyle(.roundedBorder)
            case .string:
                TextField("Value", text: stringBinding(for: example.name))
                    .textFieldStyle(.roundedBorder)
            case .array, .object, .null:
                TextEditor(text: jsonBinding(for: example.name))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 90)
                    .padding(8)
                    .background(
                        .quaternary.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
            }
        }
    }

    private func boolBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: {
                guard case let .bool(value) = argumentDrafts[key] else { return false }
                return value
            },
            set: { argumentDrafts[key] = .bool($0) }
        )
    }

    private func intBinding(for key: String) -> Binding<String> {
        Binding(
            get: {
                guard case let .int(value) = argumentDrafts[key] else { return "" }
                return String(value)
            },
            set: { newValue in
                if let value = Int(newValue) {
                    argumentDrafts[key] = .int(value)
                }
            }
        )
    }

    private func doubleBinding(for key: String) -> Binding<String> {
        Binding(
            get: {
                guard case let .double(value) = argumentDrafts[key] else { return "" }
                return String(value)
            },
            set: { newValue in
                if let value = Double(newValue) {
                    argumentDrafts[key] = .double(value)
                }
            }
        )
    }

    private func stringBinding(for key: String) -> Binding<String> {
        Binding(
            get: {
                guard case let .string(value) = argumentDrafts[key] else { return "" }
                return value
            },
            set: { argumentDrafts[key] = .string($0) }
        )
    }

    private func jsonBinding(for key: String) -> Binding<String> {
        Binding(
            get: {
                guard let value = argumentDrafts[key] else { return "null" }
                return MCPToolsBrowserJSONFormatting.prettyPrinted(value)
            },
            set: { newValue in
                if let parsed = MCPToolsBrowserJSONFormatting.parse(newValue) {
                    argumentDrafts[key] = parsed
                }
            }
        )
    }
}
