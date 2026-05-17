import Foundation

// UserDefaults is effectively thread-safe for our usage patterns here, but it is not
// declared Sendable in Foundation. Swift 6 strict concurrency requires a Sendable
// boundary when passing it into actors.
// Swift 6: `@retroactive` silences the warning about future Foundation adding this conformance.
extension UserDefaults: @retroactive @unchecked Sendable {}
