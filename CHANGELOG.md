## 0.1.2 — 2026-06-26

### Added

- **Theme-inherit window chrome** — the native macOS window title bar (and the mobile status / navigation bars on iOS · Android) now follow the launcher's effective brightness (`light` / `dark` / `system`) via an `appplayer/window` method channel plus `SystemChrome` overlay, instead of a fixed system appearance. Removes the mismatched white title bar over dark content.
- **io device capability** — policy-gated `io.*` surface with a process driver (desktop OS execution, deny-by-default · plan→commit) plus network drivers (`modbus` · `mqtt` · `http` · `scpi`), wired via the vendored `io_drivers` recipe copy.

### Changed

- App display name is now **AppPlayer** (`PRODUCT_NAME`), replacing the lowercase `appplayer` that showed in the title bar / Dock / menu bar.
- App icon set to the white AppPlayer logo (macOS AppIcon set).

### Inherited via appplayer_core

- **brain_kernel KernelApp wiring** — `AppPlayerCoreService.initialize` boots `KernelApp`, registers `standardTools(app)` (41 in-process tools), and wires the `BundleSessionBridge` lifecycle. The Standard shell adds no wiring code — it inherits this automatically by calling Core.
- **8 facade tool surfaces** — `bk.fact.*` · `bk.skill.*` · `bk.profile.*` · `bk.philosophy.*` · `bk.workflow.*` · `bk.pipeline.*` · `bk.runbook.*` · `bk.agent.*` · `bk.knowledge.*` (41 wrappers) available automatically.
- **`kb://<facade>/<id>` URI scheme** — served by `BundleSessionBridge`.
- **MCP serving** — via appplayer_core: the active bundle is exposed at `bundle://manifest.json`, and a server-served bundle is reconstructed and run identically to a local one.

### Dependencies

- `appplayer_core` `^0.1.6` → `^0.1.9`
- `mcp_bundle` `^0.4.5` · `mcp_io` `^0.2.2` · `mcp_io_process` `^0.1.1` (io device capability + internal-dep latest).

## 0.1.1

- Bumped `appplayer_core` to `^0.1.6` (mcp_ui 1.3.4 cycle: `flutter_mcp_ui_core` 0.4.0 / `flutter_mcp_ui_runtime` 0.5.0 + `mcp_bundle` 0.3.1 cascade).

## 0.1.0

- Initial open-source reference release of AppPlayer Standard.
- Composition root + adapter wiring for `appplayer_core` (secure storage, HTTP bundle fetcher, shared-prefs server store, logger, metadata sink).
- Standard tier screens — home, app renderer, dashboard, settings, onboarding, app form.
- i18n string table with English default plus Korean / Japanese / Chinese translations.
