# AppPlayer Standard — Example Bundles

Reference samples that demonstrate the three transports an AppPlayer
host accepts, all serving the **same** MCP UI DSL 1.3 content. Verify
that an app authored once renders identically regardless of how it is
delivered — over a live MCP server, off a local bundle directory, or
out of a packed `.mcpb` archive.

## Contents

| Path | Kind | Description |
| --- | --- | --- |
| `demo_showcase/` | Server (Dart) | Native MCP server (`bin/server.dart`) emitting the showcase UI over stdio. The widget gallery itself — every layout, display, input, and chart factory the runtime supports. |
| `demo_showcase.mbd/` | Bundle directory | Filesystem snapshot of the server's resource URI responses. `ui/app.json` ↔ `ui://app`, `ui/pages/layout.json` ↔ `ui://pages/layout`, etc. |
| `demo_showcase.mcpb` | Packed bundle | The `.mbd/` zipped through `mcp_bundle:pack_mbd`. What you ship to a launcher's "Install bundle" flow. |
| `demo_showcase_bundle_server/` | Bundle-backed server | Generic MCP server that loads any `.mbd/` through `McpBundleLoader` (manifest parse + schema validation) and serves its `ui/**.json` files as `ui://*` resources. Server name/version come from the parsed manifest; missing `ui://app/info` is synthesised from the manifest fields. The bundle equivalent of the native server. |
| `hello_counter.mbd/` & `.mcpb` | Minimal bundle | Single-page counter — manifest + UI + asset reference + `setState` actions. Smallest end-to-end bundle sample. |
| `tool/build_demo_showcase_bundle.dart` | Build script | Snapshots `apps/demo_ui/test/fixtures/*.json` into `demo_showcase.mbd/`. |

## The three-transport equivalence

```
                 ┌──────────────────────────────────┐
                 │          AppPlayer host          │
                 └──────────────┬───────────────────┘
                                │ MCP (resources/read, ui_action)
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
 ┌──────▼──────┐         ┌──────▼──────┐        ┌───────▼───────┐
 │ demo_       │         │ demo_       │        │ demo_         │
 │ showcase    │         │ showcase_   │        │ showcase.mcpb │
 │ (native     │         │ bundle_     │        │ (installed    │
 │ server)     │         │ server +    │        │ archive,      │
 │             │         │ .mbd/)      │        │ unpacked on   │
 │             │         │             │        │ install)      │
 └─────────────┘         └─────────────┘        └───────────────┘

 Server emits        Generic server walks    Static archive — the
 UI from Dart        a .mbd/ directory       launcher unpacks once
 code in real time.  and serves files as     and reads from disk
                     resources.              thereafter.
```

All three resolve `ui://app`, `ui://app/info`, and `ui://pages/<id>`
to byte-identical JSON. A change made to a page must produce the same
visual result no matter which transport the user picks.

## Running each variant

### 1. Native server (`demo_showcase`)

```sh
cd demo_showcase
dart pub get
dart compile exe bin/server.dart -o server
./server                 # listens on stdio
```

Add it as a server-type app in AppPlayer:

```
Add app → Server → Transport: stdio → Command: <abs path to ./server>
```

### 2. Bundle-backed server (`demo_showcase_bundle_server`)

```sh
cd demo_showcase_bundle_server
dart pub get
dart compile exe bin/server.dart -o server
./server --bundle ../demo_showcase.mbd
```

Add it as a server-type app in AppPlayer with the same stdio command
plus the `--bundle` argument.

### 3. Installed `.mcpb` archive

```
Add app → Bundle → File → demo_showcase.mcpb
```

The launcher unpacks the archive under its bundle install root and
opens the entry point declared in `manifest.json` (`ui.app`).

## Rebuilding artefacts

After editing the source UI fixtures, refresh both the `.mbd/` and
the `.mcpb`:

```sh
# 1. Snapshot the fixtures into the .mbd/ directory.
dart run os/appplayer/appplayer/dart/example/tool/build_demo_showcase_bundle.dart

# 2. Pack the .mbd/ into a .mcpb archive.
dart run mcp_bundle:pack_mbd \
  os/appplayer/appplayer/dart/example/demo_showcase.mbd \
  os/appplayer/appplayer/dart/example/demo_showcase.mcpb

# 3. Recompile the native servers so changes to bin/server.dart land.
(cd os/appplayer/appplayer/dart/example/demo_showcase && \
   dart compile exe bin/server.dart -o server)
(cd os/appplayer/appplayer/dart/example/demo_showcase_bundle_server && \
   dart compile exe bin/server.dart -o server)
```

## Theme

The showcase ships an MCP UI DSL 1.3 theme — Material 3 with a
seed-derived palette plus mode-specific `light` / `dark` overrides.
See `demo_showcase/lib/theme/showcase_theme.dart` and
`demo_showcase.mbd/ui/app.json` (kept identical by construction).

Widget colors reference the canonical M3 28-role slots
(`primary` / `onPrimary` / `surface` / `onSurface` / `outlineVariant`
/ ...). No legacy slot names (`textOnPrimary`, `background`,
`divider`) are used.

## License

MIT.
