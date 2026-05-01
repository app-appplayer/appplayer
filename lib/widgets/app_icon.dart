import 'package:flutter/material.dart';

import '../models/app_config.dart';

/// Reusable app icon widget for the launcher home grid.
class AppIconWidget extends StatelessWidget {
  const AppIconWidget({
    super.key,
    required this.app,
    required this.onTap,
    required this.onLongPress,
  });

  final AppConfig app;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const double _iconBoxSize = 48;
  static const double _iconRadius = 12;

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
    final hasNetworkIcon = app.iconUrl != null && app.iconUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: _iconBoxSize,
            height: _iconBoxSize,
            decoration: BoxDecoration(
              color: hasNetworkIcon
                  ? null
                  : _fallbackColor(cs).withValues(alpha: 0.12),
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
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: _iconBoxSize + 8,
            child: Text(
              app.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
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
