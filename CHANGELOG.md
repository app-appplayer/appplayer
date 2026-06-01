## [unreleased] — 2026-06-01

### Inherited via appplayer_core

- **brain_kernel KernelApp wiring** — `AppPlayerCoreService.initialize` boots `KernelApp`, registers `standardTools(app)` (41 in-process tools), and wires the `BundleSessionBridge` lifecycle. The Standard shell adds no wiring code — it inherits this automatically by calling Core.
- **8 facade tool surfaces** — `bk.fact.*` · `bk.skill.*` · `bk.profile.*` · `bk.philosophy.*` · `bk.workflow.*` · `bk.pipeline.*` · `bk.runbook.*` · `bk.agent.*` · `bk.knowledge.*` (41 wrappers) available automatically.
- **`kb://<facade>/<id>` URI scheme** — served by `BundleSessionBridge`.
- **MCP serving** — via appplayer_core 0.1.7: the active bundle is exposed at `bundle://manifest.json`, and a server-served bundle is reconstructed and run identically to a local one.

### Dependencies

- `appplayer_core` `^0.1.6` → `^0.1.7` (behavior definition engine + MCP serving cascade).

## 0.1.1

- Bumped `appplayer_core` to `^0.1.6` (mcp_ui 1.3.4 cycle: `flutter_mcp_ui_core` 0.4.0 / `flutter_mcp_ui_runtime` 0.5.0 + `mcp_bundle` 0.3.1 cascade).

## 0.1.0

- Initial open-source reference release of AppPlayer Standard.
- Composition root + adapter wiring for `appplayer_core` (secure storage, HTTP bundle fetcher, shared-prefs server store, logger, metadata sink).
- Standard tier screens — home, app renderer, dashboard, settings, onboarding, app form.
- i18n string table with English default plus Korean / Japanese / Chinese translations.
