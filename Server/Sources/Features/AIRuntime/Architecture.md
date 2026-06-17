# AIRuntime Architecture

`AIRuntime` owns local on-device MLX/VLM loading for prompt-cache experiments.

Rules:

- Keep the first phase local-only and focused on prompt cache warmup, persistence, restore, and suffix-only generation.
- Do not couple this feature to Issues, MCP routing, event loops, or durable workflow state yet.
- Runtime code that talks to MLX, tokenizers, filesystem model folders, or Application Support metadata belongs inside this feature.
- The public runtime API should stay usable from both SwiftUI and CLI entrypoints without duplicating inference logic.
- Prompt resources must stay bundled app resources, not duplicated under the feature folder.
