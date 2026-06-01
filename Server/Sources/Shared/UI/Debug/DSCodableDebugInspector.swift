import SwiftUI

struct DSCodableDebugInspector<Value>: View {
    let title: String
    let value: Value

    @State private var isPresented = false
    @State private var isSheetPresented = false
    @State private var jsonText: String?
    @State private var encodingErrorMessage: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(title: String, value: Value) {
        self.title = title
        self.value = value
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
            popoverContent
                .frame(width: popoverSize.width, height: popoverSize.height)
                .padding(12)
        }
        .sheet(isPresented: $isSheetPresented) {
            NavigationStack {
                popoverContent
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

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(title, systemImage: "curlybraces")
                    .font(.headline)

                Spacer(minLength: 12)

                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            if let jsonText {
                DSCodeBlock(jsonText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .lineLimit(nil)
            } else if let encodingErrorMessage {
                DSCodeBlock(encodingErrorMessage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .lineLimit(nil)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        generateJSONIfNeeded()
                    }
            }
        }
    }

    private var popoverSize: CGSize {
        let text = jsonText ?? encodingErrorMessage ?? "{}"
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let longestLineLength = lines.map(\.count).max() ?? 2
        let width = min(max(CGFloat(longestLineLength) * 7.5 + 48, 360), 920)
        let height = min(max(CGFloat(lines.count) * 16 + 86, 180), 720)
        return CGSize(width: width, height: height)
    }

    private func generateJSONIfNeeded() {
        guard jsonText == nil, encodingErrorMessage == nil else { return }
        do {
            jsonText = try DSCodableDebugMirrorJSON.prettyPrintedJSON(value)
        } catch {
            encodingErrorMessage = "Unable to encode JSON:\n\(error.localizedDescription)"
        }
    }
}

enum DSCodableDebugMirrorJSON {
    static func prettyPrintedJSON(_ value: Any) throws -> String {
        let jsonValue = toJSONValue(value, depth: 0, visited: [])
        guard JSONSerialization.isValidJSONObject(jsonValue) else {
            throw DSCodableDebugMirrorJSONError.invalidJSONObject
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
        for child in mirror.children {
            if child.label == "wrappedValue" {
                return child.value
            }
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

enum DSCodableDebugMirrorJSONError: LocalizedError {
    case invalidJSONObject

    var errorDescription: String? {
        switch self {
        case .invalidJSONObject:
            return "Value contains non-JSON-compatible types."
        }
    }
}
