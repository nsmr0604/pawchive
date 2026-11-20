# Platform abstraction migration — initial code inventory

Audit date: 2026-11-20. This is a source-level initial inventory, not an exhaustive runtime or device audit.

## Existing direct dependencies and responsibilities

| Area | Current entry points | Current direct dependency / concern | Migration target |
|---|---|---|---|
| Platform detection / layout | `src/platform.ts`, `src/App.tsx` | UA-based OS detection, layout resolution and clipboard read are mixed in a single helper; App observes window width | family runtime + OS adapter capability profile + UI layout policy |
| API and scheduler | `src/api.ts` | Tauri `invoke`, scheduler, request/cache state and settings persistence coexist | common API service, family transport adapter, Rust direct reqwest implementation |
| IndexedDB | `src/db.ts`, `src/icons.ts` | browser IndexedDB access, schema and icon cache logic | common DB/cache contracts and family-selected storage adapter |
| Settings / follows / history | `src/api.ts`, `src/follows.ts`, `src/history.ts`, `src/favstate.ts`, UI components | localStorage calls and events directly accessed in domain/UI modules | common key-value contract, platform family storage implementation |
| Logs | `src/log.ts`, `src/debug.ts`, `src/debug-log.ts`, Rust `lib.rs` | ring buffer, native file append, feature-gated debug commands, UI logging coupled | common logger/diagnostic event model; family sink and OS destination |
| Locale | `src/i18n.ts`, `src/pages/Settings.tsx`, Rust `lib.rs` | bundled translations, native list/read/write/delete locale commands and import UI | common locale overlay service and family file adapter |
| Backup / export | `src/backup.ts`, `src/pages/Settings.tsx`, Rust `lib.rs` | JSON generation plus native export and clipboard flows | common serialization/validation; family file/share/clipboard adapter |
| Diagnostics | `src/components/DeveloperDiagnostics.tsx`, `DeveloperFullDiagnostics.tsx`, `src/debug.ts` | native commands and debug build feature concerns | capability-gated diagnostics interface |
| Rust/native | `src-tauri/src/lib.rs` | API/login, PKV executor, log persistence, export, icon cache, locale operations in large module | Rust modules as OS/backend adapters with explicit family routing |
| Navigation/lifecycle | `src/App.tsx`, `src/router.ts`, `src/hooks.ts` | window resize, hashchange, scroll and back behavior directly in UI modules | UI lifecycle abstractions where native differences are material; keep ordinary DOM UI behavior common |

## Migration principles

1. Establish interface contracts and test them before moving behavior.
2. Separate shared UI/domain, common services, Desktop/Mobile family runtime, and OS adapters.
3. Avoid an OS-specific branch scattered across business/UI code; resolve capabilities and adapters centrally.
4. Preserve existing storage keys, IndexedDB schema and user data. Migration must be non-destructive and reversible where practical.
5. Preserve API request spacing/scheduler, cache behavior, Favorites cooldown, canonical server-side follow sync, PKV host/referer/user-agent policy, SSRF defenses, and secret redaction.
6. Keep Rust reqwest direct networking; do not introduce external proxy or Cloudflare infrastructure.
7. Tauri v2 invoke arguments must remain camelCase from JS.
8. Work in small PRs with CI and source-level verification; device testing remains separately reported.

## Initial audit limitations

The GitHub source search and key file inspection identified known direct dependencies. The list is a starting inventory: each migration phase must re-search and inspect call sites, including UI, native Rust commands and build configuration, before declaring an area complete.
