import Foundation

// TODO: Flow parsers should resolve identifiers from YAML-defined flows.
// Known core flow ids include loginQR, downloading, chatList and chatSelected,
// but custom/unknown YAML flow ids must remain valid.
protocol FlowParser: CrawlingParser where Output == FlowState {}
