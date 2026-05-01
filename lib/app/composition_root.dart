import 'dart:io';

import 'package:appplayer_core/appplayer_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../adapters/console_logger.dart';
import '../adapters/http_bundle_fetcher.dart';
import '../adapters/prefs_apps_registry.dart';
import '../adapters/secure_credential_vault.dart';
import '../adapters/shared_prefs_server_storage.dart';
import '../models/app_config.dart';
import '../models/apps_list_notifier.dart';
import 'app_settings.dart';
import 'host_brightness.dart';

/// Assembled services + settings exposed to the widget tree.
class AppContext {
  AppContext({
    required this.core,
    required this.settings,
    required this.serverStorage,
    required this.credentialVault,
    required this.logger,
    required this.logBuffer,
    required this.hostBrightness,
    required this.appsRegistry,
  });

  final AppPlayerCoreService core;
  final AppSettings settings;
  final SharedPrefsServerStorage serverStorage;
  final SecureCredentialVault credentialVault;
  final ConsoleLogger logger;
  final LogBuffer logBuffer;
  final HostBrightnessController hostBrightness;
  final AppsRegistry<AppConfig> appsRegistry;
}

/// MOD-SHELL-005 — single place that assembles host ports + Core + settings.
class CompositionRoot {
  const CompositionRoot._();

  static Future<AppContext> build({
    SharedPreferences? prefs,
    FlutterSecureStorage? secureStorage,
    Dio? dio,
    String? bundleInstallRootOverride,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final settings = await AppSettings.load(resolvedPrefs);

    final consoleLogger = ConsoleLogger(minLevel: settings.logLevel);
    final logBuffer = LogBuffer();
    // CompositeLogger fans out every Core diagnostic to DevTools (for
    // active development) AND to the in-app LogBuffer (for production
    // field reports). MCP server `notifications/message` lands in the
    // same LogBuffer via onMcpLogMessage below — both sources share one
    // exportable stream, distinguished by LogEntry.source.
    final logger = CompositeLogger(<Logger>[
      consoleLogger,
      BufferLogger(logBuffer),
    ]);
    final storage = SharedPrefsServerStorage(resolvedPrefs, logger: logger);
    final vault = SecureCredentialVault(
      secureStorage ?? const FlutterSecureStorage(),
    );
    final fetcher = HttpBundleFetcher(dio ?? Dio());

    final hostBrightness = HostBrightnessController(settings);
    final bundleInstallRoot =
        bundleInstallRootOverride ?? await _resolveBundleInstallRoot();

    // MOD-CORE-REG — registered-app list as core-owned reactive surface.
    // `onChanged` keeps the legacy `AppsListNotifier.revision` listeners
    // (HomeScreen / DashboardScreen still read prefs directly) alive
    // until they migrate to consuming the registry value listenable.
    final appsRegistry = PrefsAppsRegistry<AppConfig>(
      prefs: resolvedPrefs,
      storageKey: 'apps.v1',
      decode: AppConfig.decodeList,
      encode: AppConfig.encodeList,
      idOf: (a) => a.id,
      onChanged: AppsListNotifier.markDirty,
    );

    // Default sink: metadata pushes back into the registry so launcher
    // tiles re-render with fresh `name` / `iconUrl` / `metadataJson`
    // without bespoke shell wiring.
    final metadataSink = RegistryMetadataSink<AppConfig>(
      registry: appsRegistry,
      merge: (existing, m) => existing.copyWith(
        // Metadata-supplied name wins over the id-as-name fallback
        // assigned at registration time. Empty `m.name` (server omitted
        // ui://app/info) falls back to the existing AppConfig.name so
        // user edits still survive a metadata refresh.
        name: m.name.trim().isNotEmpty ? m.name.trim() : null,
        iconUrl: m.iconUri,
        metadataJson: <String, dynamic>{
          'appId': m.appId,
          'sourceKind': m.sourceKind,
          'name': m.name,
          'version': m.version,
          if (m.description != null) 'description': m.description,
          if (m.iconUri != null) 'iconUri': m.iconUri,
          if (m.splashUri != null) 'splashUri': m.splashUri,
          if (m.screenshots.isNotEmpty) 'screenshots': m.screenshots,
          if (m.category != null) 'category': m.category,
          if (m.publisher != null) 'publisher': m.publisher,
          if (m.homepage != null) 'homepage': m.homepage,
          if (m.privacyPolicy != null) 'privacyPolicy': m.privacyPolicy,
          if (m.extra.isNotEmpty) 'extra': m.extra,
        },
      ),
    );

    final core = AppPlayerCoreService();
    await core.initialize(
      storage: storage,
      bundleInstallRoot: bundleInstallRoot,
      credentialVault: vault,
      bundleFetcher: fetcher,
      appMetadataSink: metadataSink,
      logger: logger,
      hostBrightness: hostBrightness,
      // MCP `notifications/message` (logging spec) → in-app LogBuffer
      // as a LogSource.mcp entry. Core diagnostics are pushed
      // separately as LogSource.core via the CompositeLogger above.
      onMcpLogMessage: (serverId, params) {
        logBuffer.add(LogEntry.fromMcp(serverId: serverId, params: params));
      },
    );

    return AppContext(
      core: core,
      settings: settings,
      serverStorage: storage,
      credentialVault: vault,
      logger: consoleLogger,
      logBuffer: logBuffer,
      hostBrightness: hostBrightness,
      appsRegistry: appsRegistry,
    );
  }

  static Future<String> _resolveBundleInstallRoot() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}${Platform.pathSeparator}bundles');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root.path;
  }
}
