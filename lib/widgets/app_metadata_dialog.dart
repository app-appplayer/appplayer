import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../l10n/app_strings.dart';
import '../models/app_config.dart';

/// Shows §11 metadata for a launcher entry — description, version,
/// publisher, category, screenshots — rendered from the cached
/// [AppConfig.metadataJson] snapshot. Returns a silent empty-state card
/// when no metadata has been fetched yet (e.g. first registration
/// failed and the user hasn't launched the app).
class AppMetadataDialog extends StatelessWidget {
  const AppMetadataDialog({super.key, required this.app});

  final AppConfig app;

  static Future<void> show(BuildContext context, AppConfig app) {
    return showDialog<void>(
      context: context,
      builder: (_) => AppMetadataDialog(app: app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = app.metadataJson;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(app.name),
      content: SizedBox(
        width: 400,
        child: meta == null
            ? Text(S.get('meta.dialog.not_received'),
                style: theme.textTheme.bodyMedium)
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (app.iconUrl != null && app.iconUrl!.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.base),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            app.iconUrl!,
                            height: 64,
                            width: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      ),
                    if (meta['version'] is String)
                      _row(S.get('meta.version'), meta['version'] as String, theme),
                    if (meta['description'] is String)
                      _row(S.get('meta.description'), meta['description'] as String, theme),
                    if (meta['category'] is String)
                      _row(S.get('meta.category'), meta['category'] as String, theme),
                    if (meta['publisher'] is String)
                      _row(S.get('meta.publisher'), meta['publisher'] as String, theme),
                    if (meta['homepage'] is String)
                      _row(S.get('meta.homepage'), meta['homepage'] as String, theme),
                    if (meta['privacyPolicy'] is String)
                      _row(S.get('meta.privacy'),
                          meta['privacyPolicy'] as String, theme),
                    if (meta['appId'] is String)
                      _row('ID', meta['appId'] as String, theme),
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.get('common.close')),
        ),
      ],
    );
  }

  Widget _row(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
