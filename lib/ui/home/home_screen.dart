import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../../models/app_config.dart';
import '../../models/apps_list_notifier.dart';
import '../../widgets/app_metadata_dialog.dart';

/// MOD-UI-001 — Launcher-style home screen showing the app grid.
///
/// Apps are loaded from SharedPreferences key `apps.v1` via
/// [AppConfig.decodeList]. Each icon opens the app on tap and shows the
/// edit screen on long-press.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AppConfig> _apps = <AppConfig>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadApps();
    AppsListNotifier.revision.addListener(_onAppsDirty);
  }

  @override
  void dispose() {
    AppsListNotifier.revision.removeListener(_onAppsDirty);
    super.dispose();
  }

  /// Triggered by [AppsListNotifier.markDirty] from flows that replace
  /// the route stack (e.g. delete → `context.go('/')`) so the home grid
  /// doesn't keep a stale list.
  void _onAppsDirty() {
    if (!mounted) return;
    _loadApps();
  }

  /// Reads the `apps.v1` key from SharedPreferences and decodes the list.
  Future<void> _loadApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('apps.v1');
      if (!mounted) return;
      setState(() {
        _apps = AppConfig.decodeList(raw);
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.get('home.load.fail').replaceAll(r'${error}', '$e'))),
      );
    }
  }

  /// Handles tapping an app icon — routes based on [AppType].
  ///
  /// Awaits the push so the sink-updated `iconUrl` / `metadataJson`
  /// written during `openAppFromServer` is reflected on return.
  Future<void> _openApp(AppConfig app) async {
    switch (app.type) {
      case AppType.server:
        await context.push('/app/${app.serverConfigId}');
      case AppType.bundle:
        await context.push('/app/${app.id}');
      case AppType.dashboard:
        await context.push('/dashboard/${app.id}');
    }
    if (mounted) _loadApps();
  }

  /// Shows a context menu on long-press with edit / delete options.
  void _showAppMenu(BuildContext ctx, AppConfig app) {
    final renderBox = ctx.findRenderObject()! as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final overlay = Overlay.of(ctx).context.findRenderObject()! as RenderBox;

    // Anchor the menu to the tile rect, computed in overlay-relative
    // coordinates. `RelativeRect.fromLTRB` expects `right`/`bottom`
    // measured from the overlay's right/bottom edges, so use
    // `RelativeRect.fromRect` to derive them correctly — this keeps the
    // menu inside the screen even when the tile sits near the right edge.
    showMenu<String>(
      context: ctx,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      menuPadding: EdgeInsets.zero,
      // No max width — let the menu size to its longest label
      // (e.g. "Disconnect" / "Disconnected") so items don't overflow.
      constraints: const BoxConstraints(minWidth: 64),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + size.height + 2,
          size.width,
          0,
        ),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem(
          height: 28,
          value: 'info',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Theme.of(ctx).colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(S.get('home.info'), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 28,
          value: 'edit',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 14, color: Theme.of(ctx).colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(S.get('menu.edit'), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 28,
          value: 'logs',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(
                Icons.subject,
                size: 14,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(S.get('menu.logs'), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 28,
          value: 'disconnect',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(
                Icons.power_settings_new,
                size: 14,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(S.get('menu.disconnect'), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 28,
          value: 'delete',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 14, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 6),
              Text(S.get('menu.delete'), style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (!mounted) return;
      if (value == 'info') {
        await AppMetadataDialog.show(context, app);
      } else if (value == 'edit') {
        await context.push('/apps/${app.id}/edit');
        if (mounted) _loadApps();
      } else if (value == 'logs') {
        final scopeId = app.serverConfigId ?? app.bundleId ?? app.id;
        await context.push('/apps/$scopeId/logs');
      } else if (value == 'disconnect') {
        _disconnectApp(app);
      } else if (value == 'delete') {
        _deleteApp(app);
      }
    });
  }

  /// Disconnect tile action — closes whatever "active" resource the app
  /// is holding so the tile badge clears and the next open starts fresh:
  ///
  /// * **Server** — stdio / HTTP connection. `closeApp` releases the
  ///   client, stdio subprocess sees EOF and exits.
  /// * **Dashboard** — dashboard session plus every server connection it
  ///   aggregated (spec §11.9). All must be released together.
  /// * **Bundle** — no network connection; the loaded runtime is the
  ///   active resource. `closeApp` on the bundle handle destroys the
  ///   cached runtime, matching the user's mental model that bundle
  ///   "disconnect" equals "clear cache".
  Future<void> _disconnectApp(AppConfig app) async {
    try {
      await _closeAppSession(app);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.get('menu.disconnected'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.get('menu.disconnect.fail').replaceAll(r'${error}', '$e'))),
      );
    }
  }

  /// Close active session for [app] (FR-HOME-008). Shared by [_disconnectApp]
  /// and [_deleteApp] so removal always tears down runtime/caches before
  /// dropping persistent state — otherwise a reinstall with the same id
  /// would reuse the cached runtime and render stale definition.
  ///
  /// The AppHandle key must match what Core used at open time: bundle
  /// runtimes are keyed by `manifest.id` (= `app.bundleId`), not the
  /// launcher-side `app.id`. Falling back to `app.id` preserves legacy
  /// entries where `bundleId` was not yet populated.
  Future<void> _closeAppSession(AppConfig app) async {
    final core = context.read<AppPlayerCoreService>();
    switch (app.type) {
      case AppType.server:
        await core.closeApp(AppHandle.server(app.serverConfigId ?? app.id));
      case AppType.bundle:
        await core.closeApp(AppHandle.bundle(app.bundleId ?? app.id));
      case AppType.dashboard:
        try {
          await core.closeDashboard();
        } catch (_) {}
        for (final id in app.dashboardConnectionIds) {
          try {
            await core.closeApp(AppHandle.server(id));
          } catch (_) {}
        }
    }
  }

  /// Deletes an app after confirmation dialog (FR-HOME-009).
  ///
  /// Ordered close → persistent purge → launcher entry drop. The close
  /// step MUST precede the file uninstall / ServerConfig delete: if the
  /// runtime is left live, reinstalling the same id later would reuse
  /// the cached runtime and render the prior (now stale) definition.
  Future<void> _deleteApp(AppConfig app) async {
    final core = context.read<AppPlayerCoreService>();
    // Capture the registry up front so we don't reach for `context` after
    // an async gap (the close-session step awaits a runtime tear-down).
    final appsRegistry = context.read<AppsRegistry<AppConfig>>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.get('menu.delete.title')),
        content: Text(S.get('menu.delete.content').replaceAll(r'${name}', app.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.get('menu.delete.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.get('menu.delete.confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // 1. Close active session — drops runtime cache, disconnects server
      //    transport, unsubscribes resources. Silent failure here is OK:
      //    a stale close doesn't block removal, and the user's intent is
      //    final.
      try {
        await _closeAppSession(app);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.get('home.session.close.fail').replaceAll(r'${error}', '$e'))),
          );
        }
      }

      // 2. Purge persistent state per type.
      if (app.type == AppType.bundle && app.bundleId != null) {
        try {
          await core.uninstallBundle(app.bundleId!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.get('home.bundle.remove.fail').replaceAll(r'${error}', '$e'))),
            );
          }
        }
      } else if (app.type == AppType.server) {
        final serverId = app.serverConfigId ?? app.id;
        try {
          await core.deleteServer(serverId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.get('home.server_config.remove.fail').replaceAll(r'${error}', '$e'))),
            );
          }
        }
      }
      // Dashboard: slot ServerConfigs can be shared with other tiles,
      // so removal of the dashboard entry does not cascade.

      // 3. Drop launcher entry via the registry so its in-memory cache
      //    stays in sync. Bypassing the registry (raw prefs.setString)
      //    leaves a stale `value`; a subsequent metadata sink update on
      //    *any* app would re-persist that stale list and resurrect the
      //    deleted entry. The registry's `onChanged` hook also bumps
      //    AppsListNotifier so legacy prefs-direct readers refresh.
      await appsRegistry.remove(app.id);
      if (mounted) _loadApps();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.get('menu.delete.fail').replaceAll(r'${error}', '$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppPlayer'),
        actions: <Widget>[
          IconButton(
            key: const Key('home.add'),
            icon: const Icon(Icons.add),
            tooltip: S.get('home.add'),
            onPressed: () async {
              await context.push('/apps/new');
              if (mounted) _loadApps();
            },
          ),
          IconButton(
            key: const Key('home.settings'),
            icon: const Icon(Icons.settings),
            tooltip: S.get('home.settings'),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show nothing while the initial load is in flight.
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_apps.isEmpty) {
      return Center(
        key: const Key('home.empty'),
        child: Text(S.get('home.empty')),
      );
    }

    final core = context.read<AppPlayerCoreService>();
    return ListenableBuilder(
      listenable: core.lifecycleListenable,
      builder: (context, _) {
        final formFactor = FormFactor.of(context);
        final spacing = AppSpacing.of(context);
        // compact — Wrap stays aligned-left, matches mobile portrait.
        // medium / expanded / large — fluid GridView with automatic
        // column count driven by tile max extent (128 px per tile).
        if (formFactor == FormFactor.compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(spacing.base),
            child: Wrap(
              spacing: spacing.lg,
              runSpacing: spacing.lg,
              children: _apps
                  .map((app) => _AppIcon(
                        key: Key('home.app.${app.id}'),
                        app: app,
                        active: _isAppActive(core, app),
                        onTap: () => _openApp(app),
                        onLongPress: (iconCtx) => _showAppMenu(iconCtx, app),
                      ))
                  .toList(),
            ),
          );
        }
        return GridView.builder(
          padding: EdgeInsets.all(spacing.base),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 128,
            mainAxisSpacing: spacing.lg,
            crossAxisSpacing: spacing.lg,
            childAspectRatio: 0.85,
          ),
          itemCount: _apps.length,
          itemBuilder: (ctx, i) {
            final app = _apps[i];
            return _AppIcon(
              key: Key('home.app.${app.id}'),
              app: app,
              active: _isAppActive(core, app),
              onTap: () => _openApp(app),
              onLongPress: (iconCtx) => _showAppMenu(iconCtx, app),
            );
          },
        );
      },
    );
  }

  /// True when the tile should show the "connected" dot. Per spec §11.9
  /// dashboards are active when *any* of their inner server connections
  /// is live — not when all of them are. Partial connectivity is still
  /// "the dashboard has something to show", so one live slot lights the
  /// badge.
  bool _isAppActive(AppPlayerCoreService core, AppConfig app) {
    switch (app.type) {
      case AppType.server:
        return core.isServerConnected(app.serverConfigId ?? app.id);
      case AppType.bundle:
        // Core registers the bundle session under its manifest id —
        // not the launcher's generated AppConfig.id. Use bundleId when
        // set (new install flow) and fall back to app.id only for the
        // legacy shape in case a migration has not populated bundleId.
        return core.isBundleLoaded(app.bundleId ?? app.id);
      case AppType.dashboard:
        return app.dashboardConnectionIds.any(core.isServerConnected);
    }
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({
    super.key,
    required this.app,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final AppConfig app;
  final bool active;
  final VoidCallback onTap;
  final void Function(BuildContext iconContext) onLongPress;

  static const double _iconBoxSize = 48;
  static const double _iconRadius = 12;
  static const double _badgeSize = 12;

  /// Default fallback icon per app type.
  IconData get _fallbackIcon {
    switch (app.type) {
      case AppType.server:
        return Icons.dns_rounded;
      case AppType.bundle:
        return Icons.inventory_2_rounded;
      case AppType.dashboard:
        return Icons.grid_view_rounded;
    }
  }

  /// Fallback icon colour per app type.
  Color _fallbackColor(ColorScheme cs) {
    switch (app.type) {
      case AppType.server:
        return cs.primary;
      case AppType.bundle:
        return cs.tertiary;
      case AppType.dashboard:
        return cs.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: _iconBoxSize + 16,
      child: GestureDetector(
        onSecondaryTap: () => onLongPress(context),
        child: InkWell(
          onTap: onTap,
          onLongPress: () => onLongPress(context),
          borderRadius: BorderRadius.circular(_iconRadius),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildIcon(context, cs),
              const SizedBox(height: 4),
              Text(
                app.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, ColorScheme cs) {
    final hasNetworkIcon = app.iconUrl != null && app.iconUrl!.isNotEmpty;

    final iconSquare = Container(
      width: _iconBoxSize,
      height: _iconBoxSize,
      decoration: BoxDecoration(
        color: hasNetworkIcon ? null : _fallbackColor(cs).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_iconRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasNetworkIcon
          ? Image.network(
              app.iconUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultIcon(cs),
            )
          : _defaultIcon(cs),
    );

    if (!active) return iconSquare;

    // Activity badge: small green dot in the top-right corner with a
    // high-contrast ring so it reads against both light icons and dark
    // icons. Positioned *outside* the icon's clip so the ring isn't
    // clipped by the rounded corner.
    return SizedBox(
      width: _iconBoxSize,
      height: _iconBoxSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          iconSquare,
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              key: const Key('home.app.badge.active'),
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E), // green-500
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultIcon(ColorScheme cs) {
    return Center(
      child: Icon(
        _fallbackIcon,
        size: 24,
        color: _fallbackColor(cs),
      ),
    );
  }
}
