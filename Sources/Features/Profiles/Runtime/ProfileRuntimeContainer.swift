import Foundation

/// Future home for the profile-scoped service bubble.
///
/// Each running profile will eventually own its own repositories, MCP server,
/// WhatsApp runtime, assistant loop, settings, logs, and cancellation state here.
/// For now this is a lightweight placeholder so the architecture has the right
/// place to grow into.
struct ProfileRuntimeContainer: Sendable {
    let context: ProfileContext
}
