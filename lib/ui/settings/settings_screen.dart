import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../adapters/secure_credential_vault.dart';
import '../../adapters/shared_prefs_server_storage.dart';
import '../../app/app_settings.dart';
import '../../l10n/app_strings.dart';

/// MOD-UI-005 — global app settings: theme, locale, log level, data reset.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

@visibleForTesting
class SettingsScreenState extends State<SettingsScreen> {
  Future<void> _resetAll(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(S.get('settings.reset.title')),
        content: Text(S.get('settings.reset.content')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.get('settings.reset.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.get('settings.reset.confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !ctx.mounted) return;
    final storage = ctx.read<SharedPrefsServerStorage>();
    final vault = ctx.read<SecureCredentialVault>();
    final settings = ctx.read<AppSettings>();
    final messenger = ScaffoldMessenger.of(ctx);
    final errors = <String>[];
    try {
      await storage.clearAll();
    } catch (e) {
      errors.add('servers: $e');
    }
    try {
      await vault.clearAll();
    } catch (e) {
      errors.add('credentials: $e');
    }
    await settings.resetToDefaults();
    final msg = errors.isEmpty
        ? S.get('settings.reset.done')
        : S.get('settings.reset.partial').replaceAll('\${errors}', errors.join(', '));
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final formFactor = FormFactor.of(context);

    // On expanded / large windows, cap settings to a readable column
    // width — a 2000-px-wide list of controls reads as cold. Compact /
    // medium keep the full-width list native to mobile.
    final maxListWidth = formFactor.isExpandedOrLarger ? 720.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: Text(S.get('settings.title'))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxListWidth),
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
          // ── Display ──────────────────────────────────────────────────────
          _SectionTitle(S.get('settings.display')),
          SegmentedButton<ThemeMode>(
            key: const Key('settings.theme'),
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment(value: ThemeMode.system, label: Text('system')),
              ButtonSegment(value: ThemeMode.light, label: Text('light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('dark')),
            ],
            selected: <ThemeMode>{settings.themeMode},
            onSelectionChanged: (s) => settings.setThemeMode(s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── View mode (responsive-rendering plan §7.1) ───────────────────
          // Pins the global form factor. `auto` defers to MediaQuery;
          // other values override regardless of window width, with per-app
          // pins taking higher priority. The secondary label shows the
          // currently resolved class when `auto` is selected so the user
          // sees which physical form factor is in effect right now.
          _SectionTitle(S.get('settings.view_mode')),
          SegmentedButton<ViewMode>(
            key: const Key('settings.view_mode'),
            segments: const <ButtonSegment<ViewMode>>[
              ButtonSegment(value: ViewMode.auto, label: Text('auto')),
              ButtonSegment(value: ViewMode.compact, label: Text('compact')),
              ButtonSegment(value: ViewMode.medium, label: Text('medium')),
              ButtonSegment(value: ViewMode.expanded, label: Text('expanded')),
              ButtonSegment(value: ViewMode.large, label: Text('large')),
            ],
            selected: <ViewMode>{settings.defaultViewMode},
            onSelectionChanged: (s) => settings.setDefaultViewMode(s.first),
          ),
          if (settings.defaultViewMode == ViewMode.auto)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                S.get('settings.viewmode.auto.current').replaceAll(
                    r'${mode}', FormFactor.of(context).name),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _SectionTitle(S.get('settings.language')),
          DropdownButton<String>(
            key: const Key('settings.locale'),
            value: settings.locale.languageCode,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'auto', child: Text(S.get('locale.auto'))),
              DropdownMenuItem(value: 'en', child: Text(S.get('locale.en'))),
              DropdownMenuItem(value: 'ko', child: Text(S.get('locale.ko'))),
              DropdownMenuItem(value: 'ja', child: Text(S.get('locale.ja'))),
              DropdownMenuItem(value: 'zh', child: Text(S.get('locale.zh'))),
            ],
            onChanged: (v) {
              if (v != null) {
                settings.setLocale(Locale(v));
                FocusScope.of(context).unfocus();
              }
            },
          ),
          const Divider(),

          // ── Connection ──────────────────────────────────────────────────
          _SectionTitle(S.get('settings.connection')),
          OutlinedButton.icon(
            key: const Key('settings.disconnect_all'),
            icon: const Icon(Icons.link_off, size: 16),
            label: Text(S.get('settings.disconnect.all')),
            onPressed: () async {
              final core = context.read<AppPlayerCoreService>();
              try {
                for (final id in core.connections.keys.toList()) {
                  await core.closeApp(AppHandle.server(id));
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.get('settings.disconnect.all.done'))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.get('settings.disconnect.all.fail').replaceAll('\${error}', '$e'))),
                  );
                }
              }
            },
          ),
          const Divider(),

          // ── Logging ──────────────────────────────────────────────────────
          _SectionTitle(S.get('settings.logging')),
          DropdownButton<LogLevel>(
            key: const Key('settings.log_level'),
            value: settings.logLevel,
            items: LogLevel.values
                .map((l) =>
                    DropdownMenuItem(value: l, child: Text(l.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                settings.setLogLevel(v);
                FocusScope.of(context).unfocus();
              }
            },
          ),
          const Divider(),

          // ── Data reset ───────────────────────────────────────────────────
          _SectionTitle(S.get('settings.data')),
          OutlinedButton(
            key: const Key('settings.reset_all'),
            onPressed: () => _resetAll(context),
            child: Text(S.get('settings.reset.all')),
          ),
          const Divider(),

          // ── App info ─────────────────────────────────────────────────────
          _SectionTitle(S.get('settings.info')),
          const Text('App version: 0.1.0'),
          const Text(
            'Core DSL: ${MCPUIDSLVersion.current}',
            key: Key('settings.core_version'),
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
