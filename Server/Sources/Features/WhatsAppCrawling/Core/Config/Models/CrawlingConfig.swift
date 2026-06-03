import Foundation

struct CrawlingConfig: Decodable, Equatable, Sendable {
    let schemaVersion: Int
    let version: String?
    let actions: ActionConfig?
    let flows: [String: FlowConfig]
    let web: IntegrationSectionConfig?
    let native: IntegrationSectionConfig?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case version
        case actions
        case flows
        case web
        case native
    }

    init(
        schemaVersion: Int,
        version: String?,
        actions: ActionConfig?,
        flows: [String: FlowConfig],
        web: IntegrationSectionConfig?,
        native: IntegrationSectionConfig?
    ) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.actions = actions
        self.flows = flows
        self.web = web
        self.native = native
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        version = try container.decodeIfPresent(String.self, forKey: .version)
        actions = try container.decodeIfPresent(ActionConfig.self, forKey: .actions)
        flows = try container.decodeIfPresent([String: FlowConfig].self, forKey: .flows) ?? [:]
        web = try container.decodeIfPresent(IntegrationSectionConfig.self, forKey: .web)
        native = try container.decodeIfPresent(IntegrationSectionConfig.self, forKey: .native)
    }
}

struct IntegrationSectionConfig: Decodable, Equatable, Sendable {
    let schemaVersion: Int?
    let version: String?
    let type: String?
    let nodes: [String: ExtractionNodeConfig]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case version
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKey.key("schema_version"))
        version = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey.key("version"))
        type = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey.key("type"))

        var parsedNodes: [String: ExtractionNodeConfig] = [:]
        for key in container.allKeys {
            let rawKey = key.stringValue
            if rawKey == "schema_version" || rawKey == "version" || rawKey == "type" {
                continue
            }
            if let node = try? container.decode(ExtractionNodeConfig.self, forKey: key) {
                parsedNodes[rawKey] = node
            }
        }
        nodes = parsedNodes
    }
}
