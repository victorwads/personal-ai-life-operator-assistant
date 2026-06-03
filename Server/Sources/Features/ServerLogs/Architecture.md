# Server Logs Architecture

This folder owns durable local observability for server/runtime milestones.

Rules:

- Server Logs are local-only and must not use Firebase.
- Server Logs must not use UserDefaults.
- Persistence lives behind `ServerLogRepository` so storage can be replaced later.
- The current storage is SQLite because this feature needs durable append-heavy writes, indexed newest-first queries, and efficient local filtering without introducing a larger persistence framework.
- UI reads through feature/view-model boundaries and must not own SQLite or persistence logic directly.
- AI Connection and future runtime producers should write meaningful completed milestones only. Do not persist every streaming delta or raw debug event.
- Payload inspection should reuse `DSDebugObjectsInspector` rather than creating a feature-specific inspector.
