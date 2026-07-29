## 0.1.4 — 2026-07-29 — entry links (platform spec 19)

Standard becomes the **concept entry host**: a scanned or tapped link on the demo domain opens a served app on the page the medium asked for.

- Claims `demo.appplayer.app/e/*` as an Android App Link. Production media belong to the shipped product — an open-source concept build intercepting them would take over scans it cannot fully serve, and a domain is claimable by exactly one application (§3.4).
- Supported targets are `server`, `localServer` and `external`. That is not a reduced set: it is exactly the guest path the standard defines, since a guest cannot pass an account wall and therefore never needs an account-gated target. A `bundle` or `listing` entry surfaces as unsupported instead of being quietly redirected — this build ships no marketplace, and pretending otherwise is how a stale binding hides.
- `EntryLinkService` subscribes once and feeds every link through the same call, so an intercepted link, a scanner and a deferred entry are one code path (§9.2). A link on a host we do not claim is logged and dropped rather than shown to the viewer; a stream error does not cost every later scan; a failure never crashes the app it opened.
- **Built-in scanner** (`/entry/scan`, camera + `qrCode`). It is one acquisition source among three, so it produces a URL and hands it to the same call an intercepted link takes — nothing downstream knows which door the code came through. Detection is de-duplicated and guarded while a resolution is in flight, because a camera fires the same code many times a second and the first resolve would otherwise still be running when the twentieth started. Scanning a code we do not claim says so out loud: the person aimed at it deliberately, unlike a link that merely arrived.
- `routeEntryOutcome` is the **single** outcome switch. A scan and a link are the same entry (§9.2); two copies of that switch is how the two paths drift apart, and the copy that gets forgotten is the one that breaks.
- The scan affordance sits in the home chrome rather than behind a setting — a code in front of someone is a now-or-never affordance.
- **Deferred entry resumes after an install** (§3.5). Android reads the Play install referrer (`entry_code=<code>`, percent-decoded so a partitioned code space survives); other platforms have no mechanism, so the home chrome offers a way back instead of landing silently. Resolution happens **after** the install, never from an answer minted before it — custody may have changed while the store was busy. A code that survived but no longer resolves falls back to the same offer rather than a home screen that looks like the scan never happened.
- The recovery offer reaches the home screen as an explicit optional listenable rather than an ambient provider: a required one would make the chrome unmountable in tests and in any host that runs no entry links, and a bare `Provider<bool>` collides with the next boolean anyone provides.
- This build declares `canIdentify: false` — it ships no sign-in, so an entry demanding an identified viewer is refused with that reason rather than opened as a guest.
- The issuer stays **visible while their surface is shown**, not named once and dismissed: a scanned code has no address bar, so without it the viewer cannot tell whose surface they are looking at. A resolver `notice` renders alongside it.
- Trust gate (`EntryGateScreen`) names the issuer **before** anything else and says what stopped the entry, never suggesting another destination.
- When the app no longer has the page the entry named, the opened screen says so instead of silently showing its start page (§9.6).

- **Application id aligned with the tier convention** — `com.example.appplayer` (the Flutter template default) became `com.makemind.appplayer`, matching `_pro` / `_x` / `_custom`. A `com.example.*` id cannot be published and cannot back an app-link claim, so this was a prerequisite rather than a cleanup. Android namespace + Kotlin package, iOS/macOS bundle identifiers, Linux and Windows ids all moved with it.
- **iOS associated-domains entitlement** — `Runner.entitlements` declaring `applinks:demo.appplayer.app`, wired through `CODE_SIGN_ENTITLEMENTS` on all three Runner configurations (the pattern this project's macOS target already uses). Not verified by an iOS build in this workspace; the project file and both plists lint clean.

**Not done in-tree:** the domain half of the claim — `/.well-known/assetlinks.json` and `apple-app-site-association` on `demo.appplayer.app`, which does not exist yet (requested from the site owner). Until they are served, a tapped link opens a browser instead of the app on both platforms — a silent downgrade, not an error. The built-in scanner reaches the same code path meanwhile.



## 0.1.3 — 2026-07-20

### Added

- **BLE board connection** — connect to a nearby ESP32 (or other) MCP-over-BLE
  board directly from the app. Vendors the `ble_transport` recipe (layer ② of
  the extension-transport standard) onto `appplayer_core`'s layer-①
  `connectExtensionTransport` seam via `ble_extension.dart`.
- **Debug MCP host** — desktop-only, settings-gated debug MCP endpoint
  (`ui.screenshot` / `tree` / `tap` / `type`) on port 7931 (Standard) so it
  stays clear of Pro's 7930 when both run on one machine.

### Changed

- **Dependency floors raised to published artifacts** — `appplayer_core`
  `^0.1.9 → ^0.1.13`, plus direct `brain_kernel ^0.1.8` and `mcp_client ^2.1.0`
  (the BLE entry API needs `brain_kernel` directly). Resolves entirely from
  pub.dev — no path overrides.

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
