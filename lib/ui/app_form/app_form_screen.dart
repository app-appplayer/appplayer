import 'dart:math';

import 'dart:io';

import 'package:appplayer_core/appplayer_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../adapters/console_logger.dart';
import '../../l10n/app_strings.dart';
import '../../models/app_config.dart';
import 'server_config_dialog.dart';

/// Form mode — create a new app or edit an existing one.
enum AppFormMode { create, edit }

/// MOD-UI-002 — unified add/edit form for all app types.
class AppFormScreen extends StatefulWidget {
  const AppFormScreen({
    super.key,
    required this.mode,
    this.appId,
  });

  final AppFormMode mode;

  /// Non-null when [mode] is [AppFormMode.edit].
  final String? appId;

  @override
  State<AppFormScreen> createState() => _AppFormScreenState();
}

class _AppFormScreenState extends State<AppFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Top-level type selector
  AppType _selectedType = AppType.server;

  // ── Server fields ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TransportType _transportType = TransportType.stdio;

  // STDIO-specific
  final _commandCtrl = TextEditingController();
  final _argsCtrl = TextEditingController();

  // SSE / Streamable HTTP shared
  final _urlCtrl = TextEditingController();

  // ── Bundle fields ──────────────────────────────────────────────────────────
  bool _bundleFromFile = true;
  String? _bundleFilePath;
  final _bundleUrlCtrl = TextEditingController();

  /// Id of the bundle installed against this AppConfig (null before
  /// first install / when user is replacing it).
  String? _installedBundleId;

  /// Version recorded at install time (display only).
  String? _installedBundleVersion;

  // ── Dashboard fields ───────────────────────────────────────────────────────
  final _dashNameCtrl = TextEditingController();
  List<String> _connectionIds = <String>[];
  DashboardLayout _layout = DashboardLayout.grid;
  DashboardSize _gridSize = DashboardSize.twoByTwo;

  // ── Trust level (shared across app types) ─────────────────────────────────
  // Determines which `client.*` actions the runtime will execute for
  // this app. Persisted on [AppConfig.trustLevel]; read by the session
  // open paths in home / app_renderer / dashboard.
  AppTrustLevel _trustLevel = AppTrustLevel.basic;
  ViewMode _viewMode = ViewMode.auto;

  // Populated once we load existing servers for the connection picker
  List<ServerConfig> _availableServers = <ServerConfig>[];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _commandCtrl.dispose();
    _argsCtrl.dispose();
    _urlCtrl.dispose();
    _bundleUrlCtrl.dispose();
    _dashNameCtrl.dispose();
    super.dispose();
  }

  /// Loads server list and prefills form when in edit mode.
  Future<void> _initialize() async {
    try {
      final core = context.read<AppPlayerCoreService>();
      final servers = await core.listServers();
      if (!mounted) return;
      _availableServers = servers;

      if (widget.mode == AppFormMode.edit && widget.appId != null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('apps.v1');
        final apps = AppConfig.decodeList(raw);
        final cfg = apps.firstWhere(
          (a) => a.id == widget.appId,
          orElse: () => throw StateError('App not found: ${widget.appId}'),
        );
        _prefill(cfg);
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.get('form.load.fail').replaceAll(r'${error}', '$e'))),
      );
    }
  }

  /// Prefills all controllers and state fields from an existing [AppConfig].
  void _prefill(AppConfig cfg) {
    _selectedType = cfg.type;
    _trustLevel = cfg.trustLevel;
    _viewMode = cfg.viewMode;
    switch (cfg.type) {
      case AppType.server:
        _nameCtrl.text = cfg.name;
        // Load transport details from the matching ServerConfig.
        if (cfg.serverConfigId != null) {
          final srv = _availableServers
              .where((s) => s.id == cfg.serverConfigId)
              .firstOrNull;
          if (srv != null) {
            _descCtrl.text = srv.description;
            _transportType = srv.transportType;
            final tc = srv.transportConfig;
            switch (srv.transportType) {
              case TransportType.stdio:
                _commandCtrl.text = (tc['command'] as String?) ?? '';
                final arguments = tc['arguments'];
                _argsCtrl.text =
                    arguments is List ? arguments.cast<String>().join(' ') : '';
              case TransportType.sse:
                _urlCtrl.text = (tc['serverUrl'] as String?) ?? '';
              case TransportType.streamableHttp:
                _urlCtrl.text = (tc['baseUrl'] as String?) ?? '';
            }
          }
        }
      case AppType.bundle:
        // Editing an installed bundle: the file/url inputs stay blank
        // until the user picks a replacement. The currently-installed
        // id is displayed via [cfg.bundleId] in the read-only section.
        _bundleFilePath = null;
        _bundleUrlCtrl.text = '';
        _bundleFromFile = true;
        _installedBundleId = cfg.bundleId;
        _installedBundleVersion = cfg.bundleVersion;
      case AppType.dashboard:
        _dashNameCtrl.text = cfg.name;
        _connectionIds = List<String>.from(cfg.dashboardConnectionIds);
        _layout = cfg.dashboardLayout;
        _gridSize = cfg.dashboardSize;
    }
  }

  // ── Bundle file picker ─────────────────────────────────────────────────────

  Future<void> _pickBundleFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['mcpb'],
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() => _bundleFilePath = result.files.single.path);
  }

  /// Select an already-unpacked `.mbd/` directory (dev flow). The form
  /// stores the directory path in `_bundleFilePath`; the save path
  /// detects it via `FileSystemEntity.type` and routes to
  /// `installFromDirectory` instead of `installFromFile`.
  Future<void> _pickBundleDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    if (!mounted) return;
    setState(() => _bundleFilePath = result);
  }

  /// Run the installer against the current form inputs. Returns
  /// `(id, version)` on success. When the user is editing an existing
  /// bundle entry and has not picked a replacement, returns the
  /// already-installed pair so the save path proceeds unchanged. All
  /// installer errors surface via SnackBar and the method returns
  /// `null`.
  Future<({String id, String version})?> _installBundleForSave() async {
    // Hoist the logger ref before the await chain so the catch block
    // doesn't carry the widget `context` across an async gap.
    final core = context.read<AppPlayerCoreService>();
    final logger = context.read<ConsoleLogger>();
    final pickedPath = _bundleFromFile ? _bundleFilePath : null;
    final pickedUrl = _bundleFromFile ? null : _bundleUrlCtrl.text.trim();
    final hasNewSource =
        (pickedPath != null && pickedPath.isNotEmpty) ||
            (pickedUrl != null && pickedUrl.isNotEmpty);

    if (!hasNewSource) {
      if (_installedBundleId != null) {
        return (
          id: _installedBundleId!,
          version: _installedBundleVersion ?? '',
        );
      }
      _showError(S.get('form.bundle.required'));
      return null;
    }

    try {
      final InstalledAppBundle installed;
      if (pickedPath != null) {
        // `.mbd/` pick is a directory; everything else is treated as a
        // `.mcpb` file.
        final entity = await FileSystemEntity.type(pickedPath);
        if (entity == FileSystemEntityType.directory) {
          installed = await core.installBundleFromDirectory(pickedPath);
        } else {
          installed = await core.installBundleFromFile(pickedPath);
        }
      } else {
        installed = await core.installBundleFromUrl(Uri.parse(pickedUrl!));
      }
      return (id: installed.id, version: installed.version);
    } catch (e, st) {
      logger.logError('bundle.install.fail', e, st);
      _showError(S
          .get('form.bundle.install.fail')
          .replaceAll(r'${type}', '${e.runtimeType}')
          .replaceAll(r'${error}', '$e'));
      return null;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Manifest confirm dialog ────────────────────────────────────────────────

  Future<bool> _showManifestDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.get('form.bundle.confirm.title')),
        content: Text(
          _bundleFromFile
              ? S.get('form.bundle.confirm.file').replaceAll(
                    r'${path}',
                    _bundleFilePath ??
                        S.get('form.bundle.confirm.file.empty'),
                  )
              : S.get('form.bundle.confirm.url').replaceAll(
                    r'${url}',
                    _bundleUrlCtrl.text.trim(),
                  ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.get('form.bundle.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.get('form.bundle.confirm')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture providers before any awaits to avoid using `context` across
    // async gaps (the bundle install + manifest dialog awaits push state
    // off the BuildContext).
    final appsRegistry = context.read<AppsRegistry<AppConfig>>();

    if (_selectedType == AppType.bundle) {
      final proceed = await _showManifestDialog();
      if (!proceed) return;
      final installed = await _installBundleForSave();
      if (installed == null) return; // user-visible error already shown
      _installedBundleId = installed.id;
      _installedBundleVersion = installed.version;
    }

    try {
      final cfg = _buildAppConfig();
      // Persist via the registry so its in-memory cache stays in sync —
      // any subsequent metadata sink update reads from `value`, so a raw
      // prefs.setString would leave the registry stale and a later sink
      // mutation would re-persist a stale list.
      await appsRegistry.add(cfg);

      // Also persist the ServerConfig to core storage for server-type apps.
      if (_selectedType == AppType.server && mounted) {
        final core = context.read<AppPlayerCoreService>();
        final serverCfg = _buildServerConfig(id: cfg.serverConfigId!);
        await core.saveServer(serverCfg);

        // Registration-time metadata fetch: open a session solely to let
        // AppMetadataProvider publish `ui://app/info` through the sink,
        // then close immediately. Errors are swallowed — missing metadata
        // must not block app creation; subsequent launches will retry.
        _fetchInitialMetadata(core, cfg.serverConfigId!);
      }

      // Bundle-type apps: fire-and-forget metadata publish so the manifest
      // name + icon land on the registry tile right after install. The
      // installer writes to disk but does not push metadata to the sink —
      // that only happens inside `openAppFromBundle`. Open a transient
      // session purely to surface manifest-derived metadata, then close.
      if (_selectedType == AppType.bundle && mounted) {
        final core = context.read<AppPlayerCoreService>();
        _fetchBundleMetadata(core, cfg.bundleId!);
      }

      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S
                .get('form.save.fail')
                .replaceAll(r'${error}', '$e'))),
      );
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    // Capture provider before any awaits to avoid using `context` after
    // an async gap (the confirmation dialog awaits user input).
    final appsRegistry = context.read<AppsRegistry<AppConfig>>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.get('form.delete.title')),
        content: Text(S.get('form.delete.content')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.get('form.delete.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.get('form.delete.confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // Drop via registry so its in-memory cache stays in sync.
      if (widget.appId != null) {
        await appsRegistry.remove(widget.appId!);
      }
      if (!mounted) return;
      // Go straight to the home grid instead of popping — the form may
      // have been pushed from a dashboard screen that now references a
      // deleted app and would fail to reload.
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S
                .get('form.delete.fail')
                .replaceAll(r'${error}', '$e'))),
      );
    }
  }

  // ── Registration-time metadata fetch ──────────────────────────────────────

  /// Fire-and-forget best-effort fetch of `ui://app/info` right after a
  /// server-type app is created. Opens a transient session so
  /// `AppMetadataProvider` can publish metadata through the sink, then
  /// closes. Failures are swallowed so app creation is never blocked by
  /// a missing or unreachable well-known resource.
  void _fetchInitialMetadata(AppPlayerCoreService core, String serverId) {
    // ignore: unawaited_futures
    Future(() async {
      try {
        final session = await core.openAppFromServer(serverId);
        await session.close();
      } catch (_) {
        // Silent: launcher falls back to the default icon until a later
        // launch succeeds.
      }
    });
  }

  /// Fire-and-forget best-effort metadata publish for a freshly-installed
  /// bundle. `installBundleFromFile` writes to disk but does not push
  /// metadata to the sink — that only happens inside `openAppFromBundle`.
  /// Open a transient session purely to surface manifest-derived metadata
  /// (name / icon / publisher) on the registry tile, then close.
  void _fetchBundleMetadata(AppPlayerCoreService core, String bundleId) {
    // ignore: unawaited_futures
    Future(() async {
      try {
        final session =
            await core.openAppFromBundle(BundleInstalledRef(bundleId));
        await session.close();
      } catch (_) {
        // Silent: launcher falls back to the bundleId-as-name + default
        // icon until a later launch succeeds.
      }
    });
  }

  // ── Config builders ────────────────────────────────────────────────────────

  /// Generates a simple random hex ID for new app entries.
  String _generateId() {
    final rng = Random.secure();
    return List<int>.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Returns a hostname / command-derived hint usable as the server's
  /// display name when the user did not type one. The metadata sink will
  /// overwrite this with the manifest-supplied name once the server
  /// publishes `ui://app/info`.
  String _serverNameHint() {
    switch (_transportType) {
      case TransportType.stdio:
        final command = _commandCtrl.text.trim();
        return command.isEmpty ? 'Server' : command.split('/').last;
      case TransportType.sse:
      case TransportType.streamableHttp:
        final url = _urlCtrl.text.trim();
        if (url.isEmpty) return 'Server';
        return Uri.tryParse(url)?.host ?? url;
    }
  }

  /// Builds an [AppConfig] from the current form state.
  AppConfig _buildAppConfig() {
    final id = widget.appId ?? _generateId();
    switch (_selectedType) {
      case AppType.server:
        // Empty name field falls back to a transport-derived hint; the
        // metadata sink overwrites with the server-supplied `ui://app/info`
        // name when it arrives. Explicit user input wins until the next
        // metadata refresh fires.
        final typed = _nameCtrl.text.trim();
        return AppConfig(
          id: id,
          name: typed.isEmpty ? _serverNameHint() : typed,
          type: AppType.server,
          serverConfigId: id, // 1-to-1 mapping: appId == serverConfigId
          trustLevel: _trustLevel,
          viewMode: _viewMode,
        );
      case AppType.bundle:
        final bundleId = _installedBundleId!;
        // 1-to-1 mapping: AppConfig.id == bundle.manifest.id, mirroring
        // the server case (id == serverConfigId). RegistryMetadataSink
        // uses metadata.appId (= manifest.id) as the lookup key, so any
        // other id (e.g. a random hex) would silently miss the merge and
        // the launcher tile would never receive the manifest-supplied
        // name / icon. Empty name field falls back to bundleId; the
        // sink overwrites with the manifest name when the metadata fetch
        // resolves.
        final typed = _nameCtrl.text.trim();
        return AppConfig(
          id: bundleId,
          name: typed.isEmpty ? bundleId : typed,
          type: AppType.bundle,
          bundleId: bundleId,
          bundleVersion: _installedBundleVersion,
          trustLevel: _trustLevel,
          viewMode: _viewMode,
        );
      case AppType.dashboard:
        return AppConfig(
          id: id,
          name: _dashNameCtrl.text.trim(),
          type: AppType.dashboard,
          dashboardConnectionIds: _connectionIds,
          dashboardLayout: _layout,
          dashboardSize: _gridSize,
          trustLevel: _trustLevel,
          viewMode: _viewMode,
        );
    }
  }

  /// Builds a [ServerConfig] from the current server form fields.
  ServerConfig _buildServerConfig({required String id}) {
    return ServerConfig(
      id: id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      transportType: _transportType,
      transportConfig: _buildTransportConfig(),
    );
  }

  /// Encodes transport-specific fields into the config map.
  Map<String, dynamic> _buildTransportConfig() {
    switch (_transportType) {
      case TransportType.stdio:
        final arguments = _argsCtrl.text
            .trim()
            .split(' ')
            .where((s) => s.isNotEmpty)
            .toList();
        return <String, dynamic>{
          'command': _commandCtrl.text.trim(),
          'arguments': arguments,
        };
      case TransportType.sse:
        return <String, dynamic>{'serverUrl': _urlCtrl.text.trim()};
      case TransportType.streamableHttp:
        return <String, dynamic>{'baseUrl': _urlCtrl.text.trim()};
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == AppFormMode.create
              ? S.get('form.add')
              : S.get('form.edit'),
        ),
        actions: <Widget>[
          if (widget.mode == AppFormMode.edit)
            IconButton(
              key: const Key('app_form.delete'),
              icon: const Icon(Icons.delete_outline),
              tooltip: S.get('form.delete'),
              onPressed: _delete,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    // Cap the form column on expanded / large chrome so long fields read
    // as a refined column rather than stretching across a monitor.
    // Compact / medium keep the full-width form native to mobile.
    final formFactor = FormFactor.of(context);
    final maxFormWidth =
        formFactor.isExpandedOrLarger ? 720.0 : double.infinity;
    return Form(
      key: _formKey,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxFormWidth),
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
            // App type selector — only meaningful when creating a new
            // entry. On edit the type is immutable, so the segment row
            // is hidden to keep the form focused on editable fields.
            if (widget.mode == AppFormMode.create) ...<Widget>[
              SegmentedButton<AppType>(
                key: const Key('app_form.type'),
                segments: <ButtonSegment<AppType>>[
                  ButtonSegment(
                    value: AppType.server,
                    label: Text(S.get('form.server')),
                    icon: const Icon(Icons.dns),
                  ),
                  ButtonSegment(
                    value: AppType.bundle,
                    label: Text(S.get('form.bundle')),
                    icon: const Icon(Icons.folder_zip),
                  ),
                  ButtonSegment(
                    value: AppType.dashboard,
                    label: Text(S.get('form.dashboard')),
                    icon: const Icon(Icons.dashboard),
                  ),
                ],
                selected: <AppType>{_selectedType},
                onSelectionChanged: (s) =>
                    setState(() => _selectedType = s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Type-specific fields ─────────────────────────────────────────
            if (_selectedType == AppType.server) _buildServerFields(),
            if (_selectedType == AppType.bundle) _buildBundleFields(),
            if (_selectedType == AppType.dashboard) _buildDashboardFields(),

            // ── Trust level ──────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.lg),
            _buildTrustLevelSelector(),

            // ── Connection controls (edit mode, server type) ────────────────
            if (widget.mode == AppFormMode.edit &&
                _selectedType == AppType.server) ...[
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('app_form.disconnect'),
                icon: const Icon(Icons.power_settings_new, size: 16),
                label: Text(S.get('form.disconnect')),
                onPressed: () async {
                  final core = context.read<AppPlayerCoreService>();
                  try {
                    await core.closeApp(AppHandle.server(widget.appId!));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(S.get('form.disconnected'))),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(S
                              .get('form.disconnect.fail')
                              .replaceAll(r'${error}', '$e'))),
                    );
                  }
                },
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // ── Save button ──────────────────────────────────────────────────
            FilledButton(
              key: const Key('app_form.save'),
              onPressed: _save,
              child: Text(S.get('form.save')),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Server fields ──────────────────────────────────────────────────────────

  Widget _buildServerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: const Key('app_form.name'),
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: S.get('form.name'),
            hintText: S.get('form.name.hint'),
          ),
          // Optional — empty falls back to a hostname/transport-derived
          // hint at registration, then the metadata sink overwrites with
          // the server-supplied `ui://app/info` name when it arrives.
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _descCtrl,
          decoration: InputDecoration(labelText: S.get('form.desc')),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<TransportType>(
          initialValue: _transportType,
          decoration: InputDecoration(labelText: S.get('form.transport')),
          items: TransportType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.displayName),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _transportType = v);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _buildTransportFields(),
      ],
    );
  }

  /// Renders transport-specific input fields based on [_transportType].
  Widget _buildTransportFields() {
    switch (_transportType) {
      case TransportType.stdio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _commandCtrl,
                    decoration: InputDecoration(
                      labelText: S.get('form.command'),
                      hintText: S.get('form.command.hint'),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? S.get('form.command.error')
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: S.get('form.command.browse'),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null && result.files.single.path != null) {
                        _commandCtrl.text = result.files.single.path!;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _argsCtrl,
              decoration: InputDecoration(
                labelText: S.get('form.args'),
                hintText: S.get('form.args.hint'),
              ),
            ),
          ],
        );
      case TransportType.sse:
      case TransportType.streamableHttp:
        return TextFormField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            labelText: S.get('form.url'),
            hintText: _transportType == TransportType.sse
                ? 'http://localhost:3001/sse'
                : 'http://localhost:3001/mcp',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return S.get('form.url.error');
            final uri = Uri.tryParse(v.trim());
            if (uri == null || !uri.hasScheme) return S.get('form.url.invalid');
            return null;
          },
        );
    }
  }

  // ── Bundle fields ──────────────────────────────────────────────────────────

  Widget _buildBundleFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: const Key('app_form.bundle.name'),
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: S.get('form.name'),
            hintText: S.get('form.name.hint'),
          ),
          // Optional — empty falls back to the bundle's manifest.id at
          // registration, then the metadata sink overwrites with the
          // manifest-supplied name on the first openAppFromBundle.
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment(value: true, label: Text(S.get('form.bundle.file'))),
            ButtonSegment(value: false, label: Text(S.get('form.bundle.url'))),
          ],
          selected: <bool>{_bundleFromFile},
          onSelectionChanged: (s) =>
              setState(() => _bundleFromFile = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_bundleFromFile) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(S.get('form.bundle.pick.mcpb')),
                  onPressed: _pickBundleFile,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(S.get('form.bundle.pick.mbd')),
                  onPressed: _pickBundleDirectory,
                ),
              ),
            ],
          ),
          if (_bundleFilePath != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _bundleFilePath!,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ] else ...<Widget>[
          TextFormField(
            controller: _bundleUrlCtrl,
            decoration: InputDecoration(
              labelText: S.get('form.bundle.url.label'),
              hintText: S.get('form.bundle.url.hint'),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return S.get('form.url.error');
              final uri = Uri.tryParse(v.trim());
              if (uri == null || !uri.hasScheme) {
                return S.get('form.url.invalid');
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  // ── Dashboard fields ───────────────────────────────────────────────────────

  Widget _buildDashboardFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: const Key('app_form.name'),
          controller: _dashNameCtrl,
          decoration: InputDecoration(labelText: S.get('form.dash.name')),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? S.get('form.dash.name.error')
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(S.get('form.dash.connections'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        // Reorder is the stored order, which `DashboardScreen` consumes
        // 1:1 for both grid and card layouts — dragging a tile here
        // changes where it renders on the live dashboard.
        ReorderableListView.builder(
          key: const Key('app_form.connections'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _connectionIds.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final moved = _connectionIds.removeAt(oldIndex);
              _connectionIds.insert(newIndex, moved);
            });
          },
          itemBuilder: (context, index) {
            final id = _connectionIds[index];
            final server =
                _availableServers.where((s) => s.id == id).firstOrNull;
            return ListTile(
              dense: true,
              key: Key('app_form.connection.$id'),
              leading: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
              title: Text(server?.name ?? id),
              subtitle: server != null
                  ? Text(server.transportType.displayName,
                      style: Theme.of(context).textTheme.bodySmall)
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: S.get('form.dash.connection.edit'),
                    onPressed:
                        server == null ? null : () => _editConnection(server),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: S.get('form.dash.connection.remove'),
                    onPressed: () =>
                        setState(() => _connectionIds.remove(id)),
                  ),
                ],
              ),
            );
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text(S.get('form.dash.add')),
          onPressed: _addConnection,
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<DashboardLayout>(
          segments: <ButtonSegment<DashboardLayout>>[
            ButtonSegment(
                value: DashboardLayout.grid,
                label: Text(S.get('form.dash.layout.grid'))),
            ButtonSegment(
                value: DashboardLayout.card,
                label: Text(S.get('form.dash.layout.card'))),
          ],
          selected: <DashboardLayout>{_layout},
          onSelectionChanged: (s) => setState(() => _layout = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<DashboardSize>(
          initialValue: _gridSize,
          decoration: InputDecoration(labelText: S.get('form.dash.size')),
          items: DashboardSize.values
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.label),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _gridSize = v);
          },
        ),
      ],
    );
  }

  /// Opens the shared server config dialog to register a brand new MCP
  /// server and adds it to the dashboard connections. Equivalent to the
  /// server-type app create flow — authors no longer need to pre-register
  /// the server as a launcher entry first.
  Future<void> _addConnection() async {
    // Hoist the core ref before the first await — ServerConfigDialog.show
    // is async, so `context.read` afterwards would cross an async gap.
    final core = context.read<AppPlayerCoreService>();
    final created = await ServerConfigDialog.show(context);
    if (created == null) return;
    await core.saveServer(created);
    if (!mounted) return;
    setState(() {
      _availableServers = [..._availableServers, created];
      _connectionIds = [..._connectionIds, created.id];
    });
  }

  /// Edits an existing dashboard connection by reopening the same dialog
  /// prefilled. Persisted updates propagate to any other dashboards /
  /// launcher entries that reference the same serverId.
  Future<void> _editConnection(ServerConfig server) async {
    final core = context.read<AppPlayerCoreService>();
    final updated =
        await ServerConfigDialog.show(context, initial: server);
    if (updated == null) return;
    await core.saveServer(updated);
    if (!mounted) return;
    setState(() {
      _availableServers = [
        for (final s in _availableServers)
          if (s.id == updated.id) updated else s,
      ];
    });
  }

  /// Trust level dropdown — determines which `client.*` actions the
  /// runtime will execute for this app. Levels are cumulative (each
  /// grants everything the one below grants, plus more):
  /// * **basic** — system info, notification, clipboard read
  /// * **elevated** — file read, HTTP, clipboard write
  /// * **full** — file write, shell exec
  Widget _buildTrustLevelSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(S.get('form.trust.title'), style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          S.get('form.trust.description'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<AppTrustLevel>(
          key: const Key('app_form.trust_level'),
          initialValue: _trustLevel,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: <DropdownMenuItem<AppTrustLevel>>[
            DropdownMenuItem(
              value: AppTrustLevel.untrusted,
              child: Text(S.get('form.trust.untrusted'), overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: AppTrustLevel.basic,
              child: Text(S.get('form.trust.basic'), overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: AppTrustLevel.elevated,
              child: Text(S.get('form.trust.elevated'), overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: AppTrustLevel.full,
              child: Text(S.get('form.trust.full'), overflow: TextOverflow.ellipsis),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _trustLevel = v);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        // ── Per-app view-mode pin (responsive-rendering plan §7.2) ────
        Text(S.get('form.viewmode.title'), style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          S.get('form.viewmode.description'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<ViewMode>(
          key: const Key('app_form.view_mode'),
          initialValue: _viewMode,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: <DropdownMenuItem<ViewMode>>[
            DropdownMenuItem(
                value: ViewMode.auto,
                child: Text(S.get('form.viewmode.auto'))),
            DropdownMenuItem(
                value: ViewMode.compact,
                child: Text(S.get('form.viewmode.compact'))),
            DropdownMenuItem(
                value: ViewMode.medium,
                child: Text(S.get('form.viewmode.medium'))),
            DropdownMenuItem(
                value: ViewMode.expanded,
                child: Text(S.get('form.viewmode.expanded'))),
            DropdownMenuItem(
                value: ViewMode.large,
                child: Text(S.get('form.viewmode.large'))),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _viewMode = v);
          },
        ),
      ],
    );
  }
}
