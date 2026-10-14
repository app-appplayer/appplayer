import 'package:flutter/material.dart';

import 'folder_dialogs.dart';
import 'labels.dart';

/// One folder's apps, shown with the app's own tiles (same tap, same menu as
/// on the home), and renaming the folder. Follows the apps list through
/// [changes]; when the last app leaves, the folder is gone and the screen
/// closes.
class AppFolderScreen<T> extends StatefulWidget {
  const AppFolderScreen({
    super.key,
    required this.name,
    required this.appsIn,
    required this.changes,
    required this.tileBuilder,
    required this.onRename,
    required this.labels,
    this.spacing = 12,
    this.padding = const EdgeInsets.all(16),
  });

  final String name;

  /// The apps in the folder called [name], read on every change.
  final List<T> Function(String name) appsIn;

  /// Fires when the apps list changes.
  final Listenable changes;
  final Widget Function(BuildContext context, T app) tileBuilder;

  /// Moves every app in [from] into [to].
  final Future<void> Function(String from, String to) onRename;
  final AppFolderLabels labels;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  State<AppFolderScreen<T>> createState() => _AppFolderScreenState<T>();
}

class _AppFolderScreenState<T> extends State<AppFolderScreen<T>> {
  late String _name = widget.name;
  bool _closing = false;

  /// A rename moves the apps one by one, so the old name empties before the
  /// new one is shown — that is not the folder going away.
  bool _renaming = false;

  Future<void> _rename() async {
    final to = await showRenameFolderDialog(
      context,
      name: _name,
      labels: widget.labels,
    );
    if (to == null || !mounted) return;
    _renaming = true;
    try {
      await widget.onRename(_name, to);
    } finally {
      if (mounted) {
        setState(() {
          _name = to;
          _renaming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: <Widget>[
          IconButton(
            key: const Key('app_folders.screen.rename'),
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: widget.labels.rename,
            onPressed: _rename,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.changes,
        builder: (context, _) {
          final apps = widget.appsIn(_name);
          if (apps.isEmpty && !_renaming) {
            if (!_closing) {
              _closing = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).maybePop();
              });
            }
            return const SizedBox.shrink();
          }
          return SingleChildScrollView(
            padding: widget.padding,
            child: Wrap(
              spacing: widget.spacing,
              runSpacing: widget.spacing,
              children: <Widget>[
                for (final app in apps) widget.tileBuilder(context, app),
              ],
            ),
          );
        },
      ),
    );
  }
}
