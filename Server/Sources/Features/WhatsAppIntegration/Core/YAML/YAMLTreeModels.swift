import Foundation

@MainActor
final class YAMLTreeExpansionState: ObservableObject {
    enum Mode: Equatable {
        case preserveExisting
        case expandAll
        case collapseAll
    }

    @Published var mode: Mode = .preserveExisting
    @Published var revision: Int = 0

    func requestExpandAll() {
        mode = .expandAll
        revision += 1
    }

    func requestCollapseAll() {
        mode = .collapseAll
        revision += 1
    }
}

struct YAMLStructureNode: Identifiable, Equatable {
    enum Kind: Equatable {
        case object
        case array
        case scalar
    }

    let id: String
    let title: String
    let path: String
    let any: AnySendable
    let kind: Kind
    let inlineSummary: String?
    let children: [YAMLStructureNode]?

    var summaryText: String {
        switch kind {
        case .object:
            return "{\(children?.count ?? 0) keys}"
        case .array:
            return "[\(children?.count ?? 0) items]"
        case .scalar:
            return valueSummary(from: any)
        }
    }

    var specType: String? {
        guard case .object(let dict) = any else { return nil }
        return dict["type"]?.stringValue
    }

    static func from(any: AnySendable, title: String, path: String) -> YAMLStructureNode {
        switch any {
        case .object(let dict):
            let children = dict.keys.sorted().map { key in
                let childAny = dict[key] ?? .null
                return YAMLStructureNode.from(any: childAny, title: key, path: "\(path).\(key)")
            }
            return YAMLStructureNode(
                id: path,
                title: title,
                path: path,
                any: any,
                kind: .object,
                inlineSummary: nil,
                children: children
            )
        case .array(let values):
            let children = values.enumerated().map { index, item in
                YAMLStructureNode.from(any: item, title: "[\(index)]", path: "\(path)[\(index)]")
            }
            return YAMLStructureNode(
                id: path,
                title: title,
                path: path,
                any: any,
                kind: .array,
                inlineSummary: "[\(children.count) items]",
                children: children
            )
        default:
            return YAMLStructureNode(
                id: path,
                title: title,
                path: path,
                any: any,
                kind: .scalar,
                inlineSummary: valueSummary(from: any),
                children: nil
            )
        }
    }

    func find(path: String?) -> YAMLStructureNode? {
        guard let path else { return self }
        if self.path == path { return self }
        for child in children ?? [] {
            if let found = child.find(path: path) {
                return found
            }
        }
        return nil
    }
}

struct YAMLExecutionNode: Identifiable, Equatable {
    let id: String
    let title: String
    let path: String
    let any: AnySendable
    let children: [YAMLExecutionNode]?

    var isFound: Bool {
        guard case .object(let dict) = any else { return false }
        if let found = dict["found"], case .bool(let value) = found { return value }
        if let ok = dict["ok"], case .bool(let value) = ok { return value }
        return false
    }

    var hasExplicitMiss: Bool {
        guard case .object(let dict) = any else { return false }
        if case .bool(let value)? = dict["found"] { return value == false }
        if case .bool(let value)? = dict["ok"] { return value == false }
        return false
    }

    var badge: String? {
        guard case .object(let dict) = any else { return nil }
        if let count = dict["count"]?.intValue { return "count=\(count)" }
        if dict["html"] != nil { return "html" }
        if dict["outerHTML"] != nil { return "html" }
        if let value = dict["value"] {
            return shortSummary(from: value)
        }
        return nil
    }

    var summaryText: String {
        guard case .object(let dict) = any else {
            return valueSummary(from: any)
        }
        if let count = dict["count"]?.intValue { return "count=\(count)" }
        if let value = dict["value"] { return valueSummary(from: value) }
        if let html = dict["html"] { return valueSummary(from: html) }
        if let outerHTML = dict["outerHTML"] { return valueSummary(from: outerHTML) }
        return "{\(children?.count ?? 0) keys}"
    }

    static func from(any: AnySendable, title: String, path: String) -> YAMLExecutionNode {
        let children = buildChildren(any: any, basePath: path)
        return YAMLExecutionNode(id: path, title: title, path: path, any: any, children: children)
    }

    static func buildChildren(any: AnySendable, basePath: String) -> [YAMLExecutionNode]? {
        guard case .object(let dict) = any else { return nil }
        var out: [YAMLExecutionNode] = []

        if let itemsAny = dict["items"], case .array(let items) = itemsAny {
            let itemNodes: [YAMLExecutionNode] = items.enumerated().map { index, itemAny in
                YAMLExecutionNode.from(any: itemAny, title: "[\(index)]", path: "\(basePath).items[\(index)]")
            }
            if !itemNodes.isEmpty {
                out.append(YAMLExecutionNode(id: "\(basePath).items", title: "items", path: "\(basePath).items", any: itemsAny, children: itemNodes))
            }
        }

        for key in dict.keys.sorted() where key != "items" {
            let childAny = dict[key] ?? .null
            out.append(YAMLExecutionNode.from(any: childAny, title: key, path: "\(basePath).\(key)"))
        }

        return out.isEmpty ? nil : out
    }

    func find(path: String?) -> YAMLExecutionNode? {
        guard let path else { return self }
        if self.path == path { return self }
        for child in children ?? [] {
            if let found = child.find(path: path) {
                return found
            }
        }
        return nil
    }

    var itemsChildren: [YAMLExecutionNode]? {
        children?.first(where: { $0.title == "items" })?.children
    }
}

private func valueSummary(from any: AnySendable) -> String {
    switch any {
    case .null:
        return "null"
    case .bool(let value):
        return value ? "true" : "false"
    case .int(let value):
        return "\(value)"
    case .double(let value):
        return "\(value)"
    case .string(let value):
        return value
    case .array(let values):
        return "[\(values.count) items]"
    case .object(let dict):
        return "{\(dict.count) keys}"
    }
}

private func shortSummary(from any: AnySendable, maxLength: Int = 60) -> String {
    let text: String
    switch any {
    case .null:
        text = "null"
    case .bool(let value):
        text = value ? "true" : "false"
    case .int(let value):
        text = "\(value)"
    case .double(let value):
        text = "\(value)"
    case .string(let value):
        text = value.replacingOccurrences(of: "\n", with: " ")
    case .array(let values):
        text = "[\(values.count) items]"
    case .object(let dict):
        text = "{\(dict.count) keys}"
    }

    if text.count <= maxLength { return text }
    return String(text.prefix(maxLength - 1)) + "…"
}

private extension AnySendable {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }
}

