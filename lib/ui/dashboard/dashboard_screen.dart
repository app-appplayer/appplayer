import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../models/app_config.dart';
import '../../utils/trust_level_mapping.dart';
import '../../widgets/app_metadata_dialog.dart';
import '../app_form/server_config_dialog.dart';

/// MOD-UI-004 — renders a dashboard identified by [dashboardId].
///
/// Loads the [AppConfig] from SharedPreferences `apps.v1`, opens all
/// connections, and lays out slots according to the stored layout settings.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.dashboardId});

  final String dashboardId;

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

@visibleForTesting
class DashboardScreenState extends State<DashboardScreen> {
  AppConfig? _config;

  /// Maps serverId → session; null value means the slot failed to load.
  final Map<String, AppSession?> _sessions = <String, AppSession?>{};

  /// Per-slot error messages for failed connections.
  final Map<String, String> _slotErrors = <String, String>{};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAndOpen();
  }

  @override
  void dispose() {
    // Sessions are owned by the core service; nothing to release here.
    super.dispose();
  }

  /// Loads the dashboard config and opens all connections.
  Future<void> _loadAndOpen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sessions.clear();
      _slotErrors.clear();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('apps.v1');
      final apps = AppConfig.decodeList(raw);
      final cfg = apps.firstWhere(
        (a) => a.id == widget.dashboardId,
        orElse: () =>
            throw StateError('Dashboard not found: ${widget.dashboardId}'),
      );

      if (!mounted) return;
      setState(() {
        _config = cfg;
        _isLoading = false;
      });

      final core = context.read<AppPlayerCoreService>();
      await core.openDashboard(
        DashboardBundleRef(
          bundleId: cfg.id,
          source: BundleSource.synthesized,
        ),
        cfg.dashboardConnectionIds,
      );

      // Dashboard slots inherit the dashboard tile's own trust level
      // so a slot's `client.*` actions are scoped by the dashboard
      // entry the user chose, not by the server entry's standalone
      // trust. A dashboard granting only `basic` won't elevate just
      // because one of its servers has a more permissive home tile.
      final slotTrust = toRuntimeTrustLevel(cfg.trustLevel);
      for (final serverId in cfg.dashboardConnectionIds) {
        if (!mounted) return;
        try {
          final session = await core.openAppFromServer(
            serverId,
            trustLevel: slotTrust,
          );
          if (!mounted) return;
          setState(() => _sessions[serverId] = session);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _sessions[serverId] = null;
            _slotErrors[serverId] = e.toString();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _handleClose() async {
    // Close only the dashboard session — server connections are
    // deliberately left alive so they can be reused by the launcher or
    // another dashboard that references the same serverId. Explicit
    // teardown happens via the home screen dropdown disconnect action.
    try {
      await context.read<AppPlayerCoreService>().closeDashboard();
    } catch (_) {
      // Always pop even if close fails.
    }
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(_config?.name ?? S.get('dash.title.default')),
        actions: <Widget>[
          if (_config != null) ...<Widget>[
            IconButton(
              key: const Key('dashboard.add'),
              icon: const Icon(Icons.add),
              tooltip: S.get('form.dash.add'),
              onPressed: _handleAddConnection,
            ),
            IconButton(
              key: const Key('dashboard.settings'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: S.get('dash.settings'),
              onPressed: _handleOpenSettings,
            ),
          ],
          IconButton(
            key: const Key('dashboard.exit'),
            icon: const Icon(Icons.close),
            tooltip: S.get('common.close'),
            onPressed: _handleClose,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Opens the launcher's app-edit form prefilled for this dashboard so
  /// the user can rename it, switch between grid / card layout, resize,
  /// or reorder connections. Reloads the screen on return so any
  /// `dashboardConnectionIds` / layout changes surface immediately.
  Future<void> _handleOpenSettings() async {
    final cfg = _config;
    if (cfg == null) return;
    await context.push('/apps/${cfg.id}/edit');
    if (!mounted) return;
    await _loadAndOpen();
  }

  /// Opens the shared server-config dialog and appends the new
  /// connection to the live dashboard. Persists `AppConfig` and the
  /// fresh `ServerConfig`, then opens the session so the slot renders
  /// immediately.
  Future<void> _handleAddConnection() async {
    final cfg = _config;
    if (cfg == null) return;
    final core = context.read<AppPlayerCoreService>();
    final appsRegistry = context.read<AppsRegistry<AppConfig>>();
    final created = await ServerConfigDialog.show(context);
    if (created == null || !mounted) return;
    await core.saveServer(created);

    final updated = cfg.copyWith(
      dashboardConnectionIds: <String>[
        ...cfg.dashboardConnectionIds,
        created.id,
      ],
    );
    // Persist via registry so its in-memory cache stays in sync —
    // bypassing it would let a later metadata sink update re-persist a
    // stale list and clobber this connection insertion.
    await appsRegistry.update(updated);
    if (!mounted) return;
    setState(() => _config = updated);
    try {
      final session = await core.openAppFromServer(
        created.id,
        trustLevel: toRuntimeTrustLevel(updated.trustLevel),
      );
      if (!mounted) return;
      setState(() => _sessions[created.id] = session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessions[created.id] = null;
        _slotErrors[created.id] = e.toString();
      });
    }
  }

  /// Remove a connection from the dashboard. Closes the session, drops
  /// it from `AppConfig.dashboardConnectionIds`, and persists.
  Future<void> _removeConnection(String serverId) async {
    final cfg = _config;
    if (cfg == null) return;
    final core = context.read<AppPlayerCoreService>();
    final appsRegistry = context.read<AppsRegistry<AppConfig>>();
    try {
      await core.closeApp(AppHandle.server(serverId));
    } catch (_) {}
    final updated = cfg.copyWith(
      dashboardConnectionIds: cfg.dashboardConnectionIds
          .where((id) => id != serverId)
          .toList(growable: false),
    );
    // Persist via registry so its in-memory cache stays in sync.
    await appsRegistry.update(updated);
    if (!mounted) return;
    setState(() {
      _config = updated;
      _sessions.remove(serverId);
      _slotErrors.remove(serverId);
    });
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorView(
        message: _errorMessage!,
        onRetry: _loadAndOpen,
      );
    }

    final cfg = _config;
    if (cfg == null) {
      return Center(child: Text(S.get('dash.notfound')));
    }

    switch (cfg.dashboardLayout) {
      case DashboardLayout.grid:
        return _buildGrid(cfg);
      case DashboardLayout.card:
        return _buildCardList(cfg);
    }
  }

  Widget _buildGrid(AppConfig cfg) {
    // Capture the GoRouter reference once per build so the slot's
    // navigation callbacks don't re-read an arbitrary BuildContext
    // later (between push → pop, the original dashboard context can
    // end up pointing at an inactive route on some go_router paths,
    // silently dropping the second push).
    final router = GoRouter.of(context);
    final ids = cfg.dashboardConnectionIds;
    return GridView.count(
      crossAxisCount: cfg.dashboardSize.columns,
      padding: AppSpacing.screenPadding,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      children: ids
          .map((id) => Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: _DashboardSlot(
                  key: Key('dashboard.slot.$id'),
                  serverId: id,
                  session: _sessions[id],
                  errorMessage: _slotErrors[id],
                  onTap: () => router.push('/app/$id'),
                  onLongPress: (ctx) => _showSlotMenu(ctx, id),
                  onOpenApp: (_, __) => router.push('/app/$id'),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCardList(AppConfig cfg) {
    final router = GoRouter.of(context);
    final ids = cfg.dashboardConnectionIds;
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: ids.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, index) {
        final id = ids[index];
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 200,
            child: _DashboardSlot(
              key: Key('dashboard.slot.$id'),
              serverId: id,
              session: _sessions[id],
              errorMessage: _slotErrors[id],
              onTap: () => router.push('/app/$id'),
              onLongPress: (ctx) => _showSlotMenu(ctx, id),
              onOpenApp: (_, __) => router.push('/app/$id'),
            ),
          ),
        );
      },
    );
  }

  /// Popup menu for a dashboard slot (long-press / right-click). Mirrors
  /// the home grid dropdown so users can Info / Edit connection / close
  /// the single connection / remove the slot.
  void _showSlotMenu(BuildContext ctx, String serverId) {
    final renderBox = ctx.findRenderObject()! as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final cs = Theme.of(ctx).colorScheme;

    showMenu<String>(
      context: ctx,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 2,
        offset.dx + size.width,
        0,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem(
          height: 28,
          value: 'info',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Icon(Icons.info_outline, size: 14, color: cs.onSurface),
            const SizedBox(width: 6),
            Text(S.get('home.info'), style: const TextStyle(fontSize: 12)),
          ]),
        ),
        PopupMenuItem(
          height: 28,
          value: 'edit',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Icon(Icons.settings_outlined, size: 14, color: cs.onSurface),
            const SizedBox(width: 6),
            Text(S.get('menu.edit'), style: const TextStyle(fontSize: 12)),
          ]),
        ),
        PopupMenuItem(
          height: 28,
          value: 'disconnect',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Icon(Icons.power_settings_new, size: 14, color: cs.onSurface),
            const SizedBox(width: 6),
            Text(S.get('menu.disconnect'), style: const TextStyle(fontSize: 12)),
          ]),
        ),
        PopupMenuItem(
          height: 28,
          value: 'remove',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Icon(Icons.remove_circle_outline, size: 14, color: cs.error),
            const SizedBox(width: 6),
            Text(S.get('menu.delete'),
                style: TextStyle(fontSize: 12, color: cs.error)),
          ]),
        ),
      ],
    ).then((value) async {
      if (!mounted || value == null) return;
      switch (value) {
        case 'info':
          final session = _sessions[serverId];
          final meta = session?.metadata;
          if (meta == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.get('dash.meta.not_received'))),
            );
            return;
          }
          final appStub = AppConfig(
            id: meta.appId,
            name: meta.name,
            type: AppType.server,
            iconUrl: meta.iconUri,
            metadataJson: <String, dynamic>{
              'appId': meta.appId,
              'name': meta.name,
              'version': meta.version,
              if (meta.description != null) 'description': meta.description,
              if (meta.iconUri != null) 'iconUri': meta.iconUri,
              if (meta.category != null) 'category': meta.category,
              if (meta.publisher != null) 'publisher': meta.publisher,
              if (meta.homepage != null) 'homepage': meta.homepage,
            },
          );
          await AppMetadataDialog.show(context, appStub);
          break;
        case 'edit':
          final core = context.read<AppPlayerCoreService>();
          final servers = await core.listServers();
          final server = servers.where((s) => s.id == serverId).firstOrNull;
          if (server == null) return;
          if (!mounted) return;
          final updated = await ServerConfigDialog.show(
            context,
            initial: server,
          );
          if (updated == null) return;
          await core.saveServer(updated);
          break;
        case 'disconnect':
          try {
            await context
                .read<AppPlayerCoreService>()
                .closeApp(AppHandle.server(serverId));
          } catch (_) {}
          if (!mounted) return;
          setState(() => _sessions.remove(serverId));
          break;
        case 'remove':
          await _removeConnection(serverId);
          break;
      }
    });
  }
}

// ── Slot widget ──────────────────────────────────────────────────────────────

class _DashboardSlot extends StatelessWidget {
  const _DashboardSlot({
    super.key,
    required this.serverId,
    required this.session,
    required this.errorMessage,
    required this.onTap,
    required this.onLongPress,
    required this.onOpenApp,
  });

  final String serverId;

  /// Null while loading, non-null when the session is ready.
  final AppSession? session;

  final String? errorMessage;

  final VoidCallback onTap;

  /// Slot-level menu trigger. The inner [BuildContext] passed back
  /// anchors the popup to the slot's render box so the menu appears
  /// under the tile regardless of which descendant captured the gesture.
  final void Function(BuildContext inner) onLongPress;

  /// Host handler for DSL `navigation:openApp` actions fired from
  /// within the dashboard content (spec §4.3.1). Routes to the
  /// launcher's `/app/:id` flow.
  final void Function(String? appId, String? route) onOpenApp;

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (inner) {
      if (errorMessage != null) {
        return GestureDetector(
          onLongPress: () => onLongPress(inner),
          onSecondaryTap: () => onLongPress(inner),
          child: ClipRRect(
            borderRadius: AppRadii.brMd,
            child: _SlotError(message: errorMessage!),
          ),
        );
      }
      if (session == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final dashboard = session!.buildDashboardWidget(
        context: inner,
        onOpenApp: onOpenApp,
      );
      if (dashboard != null) {
        // Spec §11.9 — inner buttons/toggles still consume their own
        // taps. `deferToChild` lets long-press bubble up to this
        // wrapper only when no descendant handled it.
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onLongPress: () => onLongPress(inner),
          onSecondaryTap: () => onLongPress(inner),
          child: ClipRRect(
            borderRadius: AppRadii.brMd,
            child: dashboard,
          ),
        );
      }

      // Spec §11.9.1 fallback: no dashboard view declared → default card
      // from the session's metadata (icon + name). Tapping opens the app.
      return GestureDetector(
        onTap: onTap,
        onLongPress: () => onLongPress(inner),
        onSecondaryTap: () => onLongPress(inner),
        child: ClipRRect(
          borderRadius: AppRadii.brMd,
          child: _IconFallback(session: session!, serverId: serverId),
        ),
      );
    });
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({required this.session, required this.serverId});

  final AppSession session;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final meta = session.metadata;
    final name = meta?.name ?? serverId;
    final iconUri = meta?.iconUri;
    final theme = Theme.of(context);
    return Container(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      padding: AppSpacing.cardPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: iconUri != null && iconUri.isNotEmpty
                  ? Image.network(
                      iconUri,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.apps, color: theme.colorScheme.primary),
                    )
                  : Icon(Icons.apps, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _SlotError extends StatelessWidget {
  const _SlotError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      padding: AppSpacing.cardPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: AppIconSizes.md,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Dashboard-level error view ───────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: AppIconSizes.xl),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.base),
            FilledButton(
              onPressed: onRetry,
              child: Text(S.get('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}
