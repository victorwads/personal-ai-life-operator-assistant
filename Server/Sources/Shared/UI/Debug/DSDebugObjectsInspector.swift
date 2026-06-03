import SwiftUI

struct DebugObjectItem: Identifiable {
    let title: String
    let value: Any
    private let identity = UUID()

    init(title: String, value: Any) {
        self.title = title
        self.value = value
    }

    var id: UUID { identity }
}

struct DSDebugObjectsInspector: View {
    let title: String
    let items: [DebugObjectItem]

    @State private var isPresented = false
    @State private var isSheetPresented = false
    @State private var renderedItems: [UUID: String] = [:]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(title: String, items: [DebugObjectItem]) {
        self.title = title
        self.items = items
    }

    init(title: String, values: [String: Any]) {
        self.init(
            title: title,
            items: values.keys.sorted().map { key in
                DebugObjectItem(title: key, value: values[key] as Any)
            }
        )
    }

    var body: some View {
        Button {
            if horizontalSizeClass == .compact {
                isSheetPresented = true
            } else {
                isPresented = true
            }
        } label: {
            Image(systemName: "info.circle")
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .accessibilityLabel(title)
        }
        .buttonStyle(.plain)
        .controlSize(.mini)
        .help(title)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            inspectorContent
                .frame(width: popoverSize.width, height: popoverSize.height)
                .padding(12)
        }
        .sheet(isPresented: $isSheetPresented) {
            NavigationStack {
                inspectorContent
                    .padding(12)
                    .navigationTitle(title)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isSheetPresented = false }
                        }
                    }
            }
        }
    }

    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(title, systemImage: "curlybraces")
                    .font(.headline)

                Spacer(minLength: 12)

                Button("Close") {
                    isPresented = false
                    isSheetPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            if items.isEmpty {
                Text("No debug objects provided.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))

                                if let rendered = renderedItems[item.id] {
                                    DSCodeBlock(rendered)
                                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                                } else {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, minHeight: 72)
                                }
                            }
                        }
                    }
                }
                .task {
                    renderItemsIfNeeded()
                }
            }
        }
    }

    private var popoverSize: CGSize {
        let text = items
            .map { renderedItems[$0.id] ?? "" }
            .joined(separator: "\n")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let longestLineLength = lines.map(\.count).max() ?? 2
        let width = min(max(CGFloat(longestLineLength) * 7.5 + 64, 420), 980)
        let estimatedLineCount = max(lines.count + (items.count * 2), items.count * 6)
        let height = min(max(CGFloat(estimatedLineCount) * 16 + 110, 220), 760)
        return CGSize(width: width, height: height)
    }

    private func renderItemsIfNeeded() {
        guard renderedItems.count != items.count else { return }

        var nextRenderedItems = renderedItems
        for item in items where nextRenderedItems[item.id] == nil {
            nextRenderedItems[item.id] = DSDebugObjectFormatter.formattedText(for: item.value)
        }
        renderedItems = nextRenderedItems
    }
}

enum DSDebugObjectFormatter {
    static func formattedText(for value: Any) -> String {
        if let string = value as? String {
            return DSDebugMirrorJSON.prettyPrintedJSONString(string) ?? string
        }

        if let json = try? DSDebugMirrorJSON.prettyPrintedJSON(value) {
            return json
        }

        return mirrorText(for: value)
    }

    static func mirrorText(for value: Any) -> String {
        var visited = Set<ObjectIdentifier>()
        return render(value, label: nil, depth: 0, visited: &visited)
    }

    private static func render(
        _ value: Any,
        label: String?,
        depth: Int,
        visited: inout Set<ObjectIdentifier>
    ) -> String {
        let indent = String(repeating: "  ", count: depth)
        let prefix = label.map { "\(indent)\($0): " } ?? indent
        let unwrapped = unwrapOptional(value)

        if isNilOptional(unwrapped) {
            return "\(prefix)nil"
        }

        if isScalar(unwrapped) {
            return "\(prefix)\(String(reflecting: unwrapped))"
        }

        let mirror = Mirror(reflecting: unwrapped)

        if mirror.displayStyle == .class {
            let objectID = ObjectIdentifier(unwrapped as AnyObject)
            if visited.contains(objectID) {
                return "\(prefix)<cycle>"
            }
            visited.insert(objectID)
        }

        switch mirror.displayStyle {
        case .collection, .set:
            let children = mirror.children.enumerated().map { index, child in
                render(child.value, label: "[\(index)]", depth: depth + 1, visited: &visited)
            }
            return ([prefix + "["] + children + [indent + "]"]).joined(separator: "\n")

        case .dictionary:
            let children = mirror.children.compactMap { child -> String? in
                let entryMirror = Mirror(reflecting: child.value)
                let parts = Array(entryMirror.children)
                guard parts.count == 2 else { return nil }
                return render(parts[1].value, label: String(describing: parts[0].value), depth: depth + 1, visited: &visited)
            }
            return ([prefix + "["] + children + [indent + "]"]).joined(separator: "\n")

        case .enum:
            if mirror.children.isEmpty {
                return "\(prefix)\(String(describing: unwrapped))"
            }
            let children = mirror.children.map {
                render($0.value, label: $0.label ?? "associated", depth: depth + 1, visited: &visited)
            }
            return ([prefix + String(describing: unwrapped)] + children).joined(separator: "\n")

        case .struct, .class:
            let typeName = String(describing: Mirror(reflecting: unwrapped).subjectType)
            let children = mirror.children.map { child in
                render(child.value, label: child.label ?? "value", depth: depth + 1, visited: &visited)
            }

            if children.isEmpty {
                return "\(prefix)\(typeName)"
            }

            return ([prefix + typeName + " {"] + children + [indent + "}"]).joined(separator: "\n")

        case .optional:
            return "\(prefix)\(String(reflecting: unwrapped))"

        default:
            return "\(prefix)\(String(reflecting: unwrapped))"
        }
    }

    private static func isScalar(_ value: Any) -> Bool {
        switch value {
        case is String, is Bool, is Int, is Int8, is Int16, is Int32, is Int64,
             is UInt, is UInt8, is UInt16, is UInt32, is UInt64,
             is Float, is Double, is Date, is UUID, is URL:
            return true
        default:
            return false
        }
    }

    private static func unwrapOptional(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        if let child = mirror.children.first {
            return child.value
        }
        return value
    }

    private static func isNilOptional(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional && mirror.children.isEmpty
    }
}

enum DSDebugMirrorJSON {
    static func prettyPrintedJSONString(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }

        return prettyString.replacingOccurrences(of: "\\/", with: "/")
    }

    static func prettyPrintedJSON(_ value: Any) throws -> String {
        let jsonValue = toJSONValue(value, depth: 0, visited: [])
        guard JSONSerialization.isValidJSONObject(jsonValue) else {
            throw DSDebugMirrorJSONError.invalidJSONObject
        }
        let data = try JSONSerialization.data(withJSONObject: jsonValue, options: [.prettyPrinted, .sortedKeys])
        let string = String(data: data, encoding: .utf8) ?? ""
        return string.replacingOccurrences(of: "\\/", with: "/")
    }

    private static func toJSONValue(
        _ value: Any,
        depth: Int,
        visited: Set<ObjectIdentifier>
    ) -> Any {
        if depth >= 20 {
            return String(describing: value)
        }

        let unwrapped = unwrapOptional(value)

        if isNilOptional(unwrapped) {
            return NSNull()
        }

        if let string = unwrapped as? String { return string }
        if let bool = unwrapped as? Bool { return bool }
        if let int = unwrapped as? Int { return int }
        if let int8 = unwrapped as? Int8 { return Int(int8) }
        if let int16 = unwrapped as? Int16 { return Int(int16) }
        if let int32 = unwrapped as? Int32 { return Int(int32) }
        if let int64 = unwrapped as? Int64 { return Int(int64) }
        if let uint = unwrapped as? UInt { return Int(uint) }
        if let uint8 = unwrapped as? UInt8 { return Int(uint8) }
        if let uint16 = unwrapped as? UInt16 { return Int(uint16) }
        if let uint32 = unwrapped as? UInt32 { return Int(uint32) }
        if let uint64 = unwrapped as? UInt64 { return Int(uint64) }
        if let double = unwrapped as? Double { return double }
        if let float = unwrapped as? Float { return Double(float) }

        if let date = unwrapped as? Date {
            return iso8601String(from: date)
        }

        if let uuid = unwrapped as? UUID {
            return uuid.uuidString
        }

        if let url = unwrapped as? URL {
            return url.absoluteString
        }

        let mirror = Mirror(reflecting: unwrapped)

        if mirror.displayStyle == .collection || mirror.displayStyle == .set {
            return mirror.children.map { toJSONValue($0.value, depth: depth + 1, visited: visited) }
        }

        if mirror.displayStyle == .dictionary {
            var object: [String: Any] = [:]
            for child in mirror.children {
                let entryMirror = Mirror(reflecting: child.value)
                let parts = Array(entryMirror.children)
                guard parts.count == 2 else { continue }
                let keyString = String(describing: parts[0].value)
                object[keyString] = toJSONValue(parts[1].value, depth: depth + 1, visited: visited)
            }
            return object
        }

        if mirror.displayStyle == .enum {
            let description = String(describing: unwrapped)
            if mirror.children.isEmpty {
                return description
            }
            var payload: [String: Any] = ["case": description]
            let associated = mirror.children.map { toJSONValue($0.value, depth: depth + 1, visited: visited) }
            payload["associated"] = associated
            return payload
        }

        if mirror.displayStyle == .class {
            let objectId = ObjectIdentifier(unwrapped as AnyObject)
            if visited.contains(objectId) {
                return "<cycle>"
            }
            var visitedNext = visited
            visitedNext.insert(objectId)
            return objectFromChildren(mirror, depth: depth, visited: visitedNext)
        }

        if mirror.displayStyle == .struct {
            return objectFromChildren(mirror, depth: depth, visited: visited)
        }

        return String(describing: unwrapped)
    }

    private static func objectFromChildren(
        _ mirror: Mirror,
        depth: Int,
        visited: Set<ObjectIdentifier>
    ) -> [String: Any] {
        var object: [String: Any] = [:]

        for child in mirror.children {
            guard let label = child.label else { continue }

            if label.hasPrefix("_"), let wrappedValue = unwrapPropertyWrapper(child.value) {
                let normalizedLabel = String(label.dropFirst())
                object[normalizedLabel] = toJSONValue(wrappedValue, depth: depth + 1, visited: visited)
                continue
            }

            object[label] = toJSONValue(child.value, depth: depth + 1, visited: visited)
        }

        return object
    }

    private static func unwrapPropertyWrapper(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        for child in mirror.children where child.label == "wrappedValue" {
            return child.value
        }
        return nil
    }

    private static func unwrapOptional(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        if let child = mirror.children.first {
            return child.value
        }
        return value
    }

    private static func isNilOptional(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional && mirror.children.isEmpty
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

enum DSDebugMirrorJSONError: LocalizedError {
    case invalidJSONObject

    var errorDescription: String? {
        switch self {
        case .invalidJSONObject:
            return "Value contains non-JSON-compatible types."
        }
    }
}
