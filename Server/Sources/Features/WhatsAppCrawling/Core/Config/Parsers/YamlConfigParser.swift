import Foundation
import Yams

struct YamlConfigParser: ConfigParser {
    func parse(_ yaml: String) async -> CrawlingResult<CrawlingConfig> {
        do {
            let decoder = YAMLDecoder()
            let config = try decoder.decode(CrawlingConfig.self, from: yaml)
            return .success(config)
        } catch {
            return .failure(.parsingFailed(error.localizedDescription))
        }
    }
}
