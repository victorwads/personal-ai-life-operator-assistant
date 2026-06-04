import Foundation

@MainActor
struct FeatureWindowsContext {
    let show: (FeatureWindowRequest) -> Void
    let hide: (String) -> Void
}
