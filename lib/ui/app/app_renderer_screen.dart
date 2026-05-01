import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../../models/app_config.dart';
import '../../utils/trust_level_mapping.dart';

/// MOD-UI-003 — hosts an [AppSession] for a single app screen.
///
/// The session already wires tool call / resource subscribe / notification
/// routing internally, so this screen simply delegates [AppSession.buildWidget]
/// to Flutter.
class AppRendererScreen extends StatefulWidget {
  const AppRendererScreen({
    super.key,
    required this.serverId,
    this.preloadedSession,
  });

  final String serverId;

  /// Pre-opened session (e.g. from bundle open in HomeScreen).
  final AppSession? preloadedSession;

  @override
  State<AppRendererScreen> createState() => AppRendererScreenState();
}

@visibleForTesting
class AppRendererScreenState extends State<AppRendererScreen> {
  AppSession? _session;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ensureSession();
  }

  Future<void> _ensureSession() async {
    if (widget.preloadedSession != null) {
      setState(() => _session = widget.preloadedSession);
      return;
    }
    final core = context.read<AppPlayerCoreService>();
    try {
      final app = await _loadAppConfig(widget.serverId);
      final trust = toRuntimeTrustLevel(app?.trustLevel ?? AppTrustLevel.basic);
      final AppSession session;
      if (app?.type == AppType.bundle) {
        session = await _openBundleSession(core: core, app: app!, trust: trust);
      } else {
        session = await core.openAppFromServer(
          app?.serverConfigId ?? widget.serverId,
          trustLevel: trust,
        );
      }
      if (!mounted) return;
      setState(() => _session = session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<AppSession> _openBundleSession({
    required AppPlayerCoreService core,
    required AppConfig app,
    required TrustLevel trust,
  }) async {
    final bundleId = app.bundleId;
    if (bundleId == null || bundleId.isEmpty) {
      throw StateError('Bundle app has no bundleId: ${app.id}');
    }
    // BundleInstalledRef keeps McpBundle.directory live so the Core's
    // filesystem-snapshot adapter can read ui/app.json from disk. A
    // BundleInlineRef round-trip here would drop `directory` (it's not in
    // the schema `toJson` emits) and trip unsupportedEntryPoint.
    return core.openAppFromBundle(
      BundleInstalledRef(bundleId),
      trustLevel: trust,
    );
  }

  Future<AppConfig?> _loadAppConfig(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('apps.v1');
    final apps = AppConfig.decodeList(raw);
    return apps
        .where((a) =>
            a.id == appId ||
            a.serverConfigId == appId ||
            a.bundleId == appId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: _ErrorBanner(
          error: _error!,
          onRetry: () {
            setState(() => _error = null);
            _ensureSession();
          },
        ),
      );
    }

    final session = _session;
    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No host chrome: server apps get their AppBar from
    // ApplicationShell (navigation / drawer / tabs) and bundle apps get
    // theirs from the bundle's own page definition (title surfaced via
    // MCPPageWidget's Scaffold wrap). Only the dashboard screen has no
    // native runtime AppBar, so the launcher adds chrome there only.
    // Close flow still runs through `onExit` so bundles / server apps
    // that expose their own exit action pop back to the launcher.
    return session.buildWidget(
      context: context,
      // Routed via go_router — `context.pop()` unwinds the GoRouter
      // stack back to the launcher home; `Navigator.of(context).pop()`
      // can pop the nested MaterialApp the runtime builds for its own
      // pages and leave the renderer screen lingering.
      onExit: () => context.pop(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String msg;
    if (error is ServerNotFoundException) {
      msg = S.get('renderer.error.notfound');
    } else if (error is ConnectionFailedException) {
      msg = S.get('renderer.error.connection')
          .replaceAll(r'${msg}', (error as ConnectionFailedException).message);
    } else if (error is BundleLoadException) {
      final e = error as BundleLoadException;
      msg = S.get('form.bundle.install.fail')
          .replaceAll(r'${type}', 'bundle.load')
          .replaceAll(r'${error}', e.reason.name);
    } else if (error is BundleAdaptException) {
      final e = error as BundleAdaptException;
      msg = S.get('form.bundle.install.fail')
          .replaceAll(r'${type}', 'bundle.adapt')
          .replaceAll(r'${error}', e.reason.name);
    } else {
      msg = S.get('renderer.error.generic').replaceAll(r'${error}', '$error');
    }
    return Center(
      key: const Key('app_renderer.error_banner'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: AppIconSizes.xl),
          const SizedBox(height: AppSpacing.sm),
          Text(msg),
          const SizedBox(height: AppSpacing.base),
          FilledButton(onPressed: onRetry, child: Text(S.get('renderer.retry'))),
        ],
      ),
    );
  }
}
