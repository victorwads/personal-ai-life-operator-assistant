# AI Connection Architecture

This document owns model host / AI provider connection rules, provider session supervision, and optional provider event stream observation.

## Provider session supervision

The app is expected to supervise provider sessions instead of relying on a long manual chat session in a UI.

This means:

- launching and pausing assistant sessions
- observing streaming events when available
- recovering from stalls or invalid tool behavior
- rebuilding context when necessary
- separating operational reasoning from social rendering

LM Studio is one example of a local inference host that can provide a session surface; the architecture should stay provider-neutral.

## Provider event stream

When the app talks to a model host using a streaming API, it can observe events such as:

- chat lifecycle events
- model loading events
- prompt processing events
- reasoning deltas
- tool call boundaries
- message deltas
- errors
- final response completion

That event stream is useful both for supervision and for future UI surfaces that show what the model is doing in real time.
This is planned work in the rewrite scaffold (the UI surfaces and supervision wiring are not fully implemented yet).

