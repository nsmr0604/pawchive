# Platform-independent foundation and adapters

## Goal

Consolidate cross-platform operations behind common interfaces while retaining platform-specific execution in adapters. Supported targets: Windows, macOS, Linux, Android and iOS. This is a migration target; this document does not claim the refactor is already implemented.

## Target architecture: common -> platform-family intermediate -> OS adapter

The current code has some responsive desktop/mobile UI branching, but the repository does **not yet implement a consistent desktop/mobile intermediate processing layer**. `src/platform.ts` currently mostly detects UA, resolves layout, and handles clipboard text; platform-specific responsibilities remain scattered across TypeScript and Rust command implementations. Treat the whole codebase as a refactor target.

Target dependency direction is a four-tier structure:

1. **Common UI and domain**: pages/components, translation merging, domain workflows and state logic.
2. **Common foundation**: stable services/contracts for storage, logging, cache/database, networking, permissions, file exports, clipboard, lifecycle, capability reporting.
3. **Platform-family intermediate layers**: Desktop runtime (shared Windows/macOS/Linux behavior and APIs) and Mobile runtime (shared Android/iOS behavior, mobile lifecycle and permission/file-sharing contracts). Each implements the common contracts and encapsulates family-specific differences.
4. **OS-specific adapters**: Windows, macOS, Linux, Android and iOS implementations where APIs, paths, permission policies, native integrations or behavior differ.

Common UI/domain/foundation must not import OS APIs, Tauri plugins, platform-specific paths or native command details directly. Platform-family layers must not contain OS-specific branching beyond routing through explicit OS adapters/capabilities. The OS adapters are the only layer that should execute native/platform-specific details.

Keep adapter selection centralized in bootstrap/capability resolution; do not proliferate duplicated UA detection or scattered `if Android` checks.

The existing `src/platform.ts` platform detection and layout helpers remain a compatibility entry point initially; gradually move capability and adapter selection into a platform bootstrap without duplicating platform detection.

## Common contracts

- **Storage**: Primary and optional Secondary roots; read/write/append/list/remove/create-directory, metadata and atomic-write where supported. Primary is private app storage. Secondary is user-accessible storage; capability availability and limits are surfaced, never silently assumed.
- **Logging**: shared structured events, levels, ring buffer, formatting, retention policy and routing. Native persistence sinks are adapters. Preserve Lite/Full logging scope, redaction and release feature gating. Lite API failure details remain destination + response body as currently specified; Full diagnostics remain debug-only.
- **Database**: common repository/domain operations, schema/version migration, transaction/error semantics and cache invalidation. Platform adapter owns IndexedDB/native persistence choices. Migration must preserve existing creator packs, seen state, icon cache, favorites/follows and settings; no destructive migration.
- **Cache**: common policy (TTL, keying, invalidation, size/eviction contracts) and repositories; persistence backend is adapter-owned. Existing API scheduler, request spacing, TTL and Favorites cooldown remain.
- **Networking**: common request/response model, Pawchive API client, scheduling, retry/cancellation policy, cache and error mapping. Adapter owns actual HTTP execution. Desktop/mobile should share policy and reqwest semantics. Keep direct Rust reqwest; do not add Cloudflare or external reverse-proxy infrastructure.
- **PKV proxy**: common target allowlist, canonical Referer/UA policy, validation and error contracts; platform executor routes through native adapter. Pawchive hosts remain direct and never use PKV. Preserve SSRF protections and sensitive-data log redaction.
- **Permissions and capability**: common capability state / request / result types. Android SAF/scoped storage, iOS sandbox/security-scoped access, and desktop paths/dialogs are adapter implementations; avoid raw path assumptions on mobile.
- **Export/import and file sharing**: common archive/JSON validation, export generation and restore policy. Adapters implement destination/save/share presentation.
- **Clipboard and external navigation**: common interface and safe error semantics; adapter performs platform operations.
- **App environment/config**: common configuration contracts, adapter supplies platform paths, OS version/capabilities and app lifecycle hooks.

## Primary/Secondary semantics

Primary is required and app-private: language resources, ordinary logs, internal state and databases/cache according to their existing ownership. Secondary is optional, user-accessible: user exports/log dumps and supplemental language JSON. Language loading order is Primary then Secondary, with Secondary overriding duplicate keys. A missing/unavailable Secondary must not prevent app startup.

Android Secondary candidate: app-specific external storage under `Android/data/<package>/files/`, with `languages/` and `exports/`; use platform APIs to resolve, not hard-coded absolute paths. iOS Secondary must be exposed to Files through a supported app container/document mechanism; access is capability-based and can be unavailable. Desktop Secondary is a user-accessible app folder.

Language JSON import UI is developer-build-only; release UI must hide it, but loading externally stored supplemental language files remains enabled in release. Validated imports are saved to Secondary.

## Migration plan (incremental, not one breaking rewrite)

1. Inventory direct platform/IO/native/database/network imports and document callsites, tests and invariants.
2. Define typed interfaces and adapter selection/initialization; add capability reporting.
3. Route logging and filesystem operations through adapters, preserve outputs and redaction.
4. Route database/cache repositories and migrations; verify existing data continuity.
5. Consolidate API networking/scheduler and PKV policy with native executor adapters; preserve direct reqwest and current API behavior.
6. Implement Secondary storage, language overlay/import and dump export per platform.
7. Remove direct platform calls from common/domain modules, add static guard tests and cross-platform CI.

Each step should be independently reviewable and tested; no platform migration should delete or overwrite user data. Native/device verification is separate from CI.

## Non-negotiable invariants

- Direct reqwest networking; no Cloudflare Pages/Workers/Functions or external reverse proxy.
- Tauri v2 JS command arguments use camelCase.
- Preserve API scheduler/cache, Favorites cooldown, canonical follow sync and post context.
- Preserve PKV host restrictions, Referer/UA rules, SSRF safeguards and log redaction.
- Keep debug diagnostics build-gated; do not leak credentials/session secrets.
- Keep platform-specific paths/API calls inside adapter modules.


## Current-code audit (main snapshot examined 2026-11-20)

Observed partial separation is inconsistent and not a complete family-layer architecture:

- `src/platform.ts`: UA detection (`getPlatform`), mobile/Desktop classification, layout resolution and clipboard-read helper. It does not provide a desktop/mobile processing intermediate layer.
- `src/api.ts`: direct Tauri `invoke("api_request")`, settings stored directly in `localStorage`, request scheduling and in-memory GET cache coupled in the module.
- `src/db.ts`: direct IndexedDB access and schema/open/transaction logic in the domain-facing module.
- `src/log.ts`: memory ring-buffer logging and direct dynamic-import routing to debug file logging.
- `src/follows.ts`, `src/history.ts`, and settings: direct `localStorage` use.
- `src/i18n.ts`: invokes native `list_locale_files`; locale loading and overlay logic otherwise lives in TypeScript.
- `src/backup.ts`: directly invokes native `export_file`.
- `src/debug.ts` and diagnostics UI: native log-file operations and export/open-folder commands.
- `src-tauri/src/lib.rs`: API/login HTTP clients, PKV HTTP executor/protocol, app-data log writing, backup export, icon cache, locale files and debug log operations are grouped into a large Rust module rather than platform/family adapter modules.
- Responsive desktop/mobile UI and Android back handling exist in `App.tsx`, but are not a general processing layer that owns platform-dependent services.

This inventory is an initial audit, not exhaustive; continue repository-wide import/call-site mapping during implementation and expand tests before migrating behavior.
