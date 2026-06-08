import Foundation

extension AIConnectionCacheMode {
    var cacheEnabled: Bool {
        switch self {
        case .automatic:
            return true
        case .disabled:
            return false
        }
    }
}
