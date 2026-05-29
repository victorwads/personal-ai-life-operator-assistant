# Issues Architecture

This document owns issue/subject lifecycle rules and issue-focused operational behavior.

## Subjects / Issues lifecycle

In the v2 rewrite, the current abstraction is `issues` (finite threads of work with a beginning/middle/end), as reflected by the MCP tools under `Sources/Features/Issues/`.

The assistant can:

- create an issue when a new thread of work appears
- update it as more information arrives
- attach external references such as chat IDs, future Gmail threads, or calendar IDs
- resolve or cancel it when the work is done
- list active issues to recover operational context after waiting or restarting

This is one of the ways the runtime avoids relying only on the model host chat context.

