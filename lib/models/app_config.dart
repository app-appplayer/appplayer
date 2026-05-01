import 'dart:convert';

import 'package:appplayer_core/appplayer_core.dart' show HasAppHandle, ViewMode;

/// Type of an app entry on the launcher home screen.
enum AppType { server, bundle, dashboard }

/// Layout mode for dashboard view.
enum DashboardLayout { grid, card }

/// Trust level granted to an app. Gates the `client.*` actions the
/// runtime will execute. Mirrors `TrustLevel` in
/// `flutter_mcp_ui_runtime`; kept as a separate enum here so persisted
/// `apps.v1` entries don't carry a runtime dependency. Mapping happens
/// at open time in [_HomeScreenState._openApp].
enum AppTrustLevel { untrusted, basic, elevated, full }

/// Grid size preset for dashboard layout.
enum DashboardSize {
  twoByTwo('2×2', 2, 2),
  twoByThree('2×3', 2, 3),
  twoByFour('2×4', 2, 4),
  threeByThree('3×3', 3, 3);

  const DashboardSize(this.label, this.columns, this.rows);
  final String label;
  final int columns;
  final int rows;
}

/// A single app entry persisted in SharedPreferences `apps.v1`.
class AppConfig implements HasAppHandle {
  AppConfig({
    required this.id,
    required this.name,
    required this.type,
    this.iconUrl,
    this.metadataJson,
    this.serverConfigId,
    this.bundleId,
    this.bundleVersion,
    this.dashboardConnectionIds = const <String>[],
    this.dashboardLayout = DashboardLayout.grid,
    this.dashboardSize = DashboardSize.twoByTwo,
    this.trustLevel = AppTrustLevel.basic,
    this.viewMode = ViewMode.auto,
  });

  @override
  final String id;
  final String name;
  final AppType type;

  @override
  String get handleKind => switch (type) {
        AppType.server => 'server',
        AppType.bundle => 'bundle',
        AppType.dashboard => 'dashboard',
      };

  /// Icon URI from server metadata (AppMetadata.iconUri). Null = default icon.
  final String? iconUrl;

  /// Full metadata snapshot (serialised AppMetadata) kept alongside
  /// [iconUrl] so the launcher can render an Info dialog without a
  /// second fetch. Fields: appId, name, version, description, iconUri,
  /// category, publisher, homepage, privacyPolicy, screenshots, extra.
  final Map<String, dynamic>? metadataJson;

  // Server type
  @override
  final String? serverConfigId;

  // Bundle type — installed bundle reference produced by
  // `McpBundleInstaller`. Launch uses this id to locate the `.mbd/`
  // directory under `BundleInstallRoot.path`; the absolute install
  // path is never persisted.
  @override
  final String? bundleId;

  /// Version recorded at install time for display only.
  final String? bundleVersion;

  // Dashboard type
  @override
  final List<String> dashboardConnectionIds;
  final DashboardLayout dashboardLayout;
  final DashboardSize dashboardSize;

  /// Trust level granted to this app — controls which `client.*`
  /// actions the runtime will execute. Default `basic` covers
  /// read-only system surfaces (info / notification / clipboard read).
  final AppTrustLevel trustLevel;

  /// Per-app view-mode pin (responsive-rendering plan §4, rung 1).
  /// Default [ViewMode.auto] defers to the global pin / DSL hint /
  /// MediaQuery chain. Any concrete value forces the form factor for
  /// this app regardless of window width.
  final ViewMode viewMode;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AppType.values.firstWhere((e) => e.name == json['type']),
      iconUrl: json['iconUrl'] as String?,
      metadataJson: json['metadataJson'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadataJson'] as Map)
          : null,
      serverConfigId: json['serverConfigId'] as String?,
      bundleId: json['bundleId'] as String?,
      bundleVersion: json['bundleVersion'] as String?,
      dashboardConnectionIds:
          (json['dashboardConnectionIds'] as List<dynamic>?)
                  ?.cast<String>() ??
              const <String>[],
      dashboardLayout: DashboardLayout.values.firstWhere(
        (e) => e.name == json['dashboardLayout'],
        orElse: () => DashboardLayout.grid,
      ),
      dashboardSize: DashboardSize.values.firstWhere(
        (e) => e.name == json['dashboardSize'],
        orElse: () => DashboardSize.twoByTwo,
      ),
      trustLevel: AppTrustLevel.values.firstWhere(
        (e) => e.name == json['trustLevel'],
        orElse: () => AppTrustLevel.basic,
      ),
      viewMode: ViewMode.parse(json['viewMode']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        if (iconUrl != null) 'iconUrl': iconUrl,
        if (metadataJson != null) 'metadataJson': metadataJson,
        if (serverConfigId != null) 'serverConfigId': serverConfigId,
        if (bundleId != null) 'bundleId': bundleId,
        if (bundleVersion != null) 'bundleVersion': bundleVersion,
        if (dashboardConnectionIds.isNotEmpty)
          'dashboardConnectionIds': dashboardConnectionIds,
        'dashboardLayout': dashboardLayout.name,
        'dashboardSize': dashboardSize.name,
        'trustLevel': trustLevel.name,
        if (viewMode != ViewMode.auto) 'viewMode': viewMode.value,
      };

  AppConfig copyWith({
    String? id,
    String? name,
    AppType? type,
    String? iconUrl,
    Map<String, dynamic>? metadataJson,
    String? serverConfigId,
    String? bundleId,
    String? bundleVersion,
    List<String>? dashboardConnectionIds,
    DashboardLayout? dashboardLayout,
    DashboardSize? dashboardSize,
    AppTrustLevel? trustLevel,
    ViewMode? viewMode,
  }) {
    return AppConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconUrl: iconUrl ?? this.iconUrl,
      metadataJson: metadataJson ?? this.metadataJson,
      serverConfigId: serverConfigId ?? this.serverConfigId,
      bundleId: bundleId ?? this.bundleId,
      bundleVersion: bundleVersion ?? this.bundleVersion,
      dashboardConnectionIds:
          dashboardConnectionIds ?? this.dashboardConnectionIds,
      dashboardLayout: dashboardLayout ?? this.dashboardLayout,
      dashboardSize: dashboardSize ?? this.dashboardSize,
      trustLevel: trustLevel ?? this.trustLevel,
      viewMode: viewMode ?? this.viewMode,
    );
  }

  /// Load app list from SharedPreferences.
  static List<AppConfig> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <AppConfig>[];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(AppConfig.fromJson)
        .toList();
  }

  /// Encode app list for SharedPreferences.
  static String encodeList(List<AppConfig> apps) {
    return jsonEncode(apps.map((a) => a.toJson()).toList());
  }
}
