import 'package:flutter/material.dart';

import 'folder_layout.dart';
import 'labels.dart';

/// What the person chose in the move dialog.
sealed class FolderMove {
  const FolderMove();
}

/// Put the app in the folder [name] (an existing one, or a new one).
final class MoveIntoFolder extends FolderMove {
  const MoveIntoFolder(this.name);
  final String name;
}

/// Take the app out of its folder, back onto the home.
final class TakeOutOfFolder extends FolderMove {
  const TakeOutOfFolder();
}

/// Asks where an app goes: one of [existing] folders, or a new name typed in.
/// [current] is the folder it is in now (offered as taken-out, not as a
/// target). Null when the person cancels or picks where it already is.
Future<FolderMove?> showMoveToFolderDialog(
  BuildContext context, {
  required List<String> existing,
  required String? current,
  required AppFolderLabels labels,
}) {
  return showDialog<FolderMove>(
    context: context,
    builder: (_) => _MoveDialog(
      existing: existing,
      current: normalizeFolderName(current),
      labels: labels,
    ),
  );
}

class _MoveDialog extends StatefulWidget {
  const _MoveDialog({
    required this.existing,
    required this.current,
    required this.labels,
  });

  final List<String> existing;
  final String? current;
  final AppFolderLabels labels;

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  final TextEditingController _name = TextEditingController();
  String? _picked;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      // Typing a name chooses it over a folder picked from the list.
      if (_name.text.trim().isNotEmpty && _picked != null) {
        setState(() => _picked = null);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _target => normalizeFolderName(_name.text) ?? _picked;

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    final targets = widget.existing.where((n) => n != widget.current).toList();
    final target = _target;
    return AlertDialog(
      title: Text(l.moveTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (targets.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final n in targets)
                      ListTile(
                        key: Key('app_folders.move.$n'),
                        dense: true,
                        leading: Icon(
                          _picked == n ? Icons.folder : Icons.folder_outlined,
                        ),
                        title: Text(n),
                        selected: _picked == n,
                        onTap: () => setState(() {
                          _picked = n;
                          _name.clear();
                        }),
                      ),
                  ],
                ),
              ),
            TextField(
              key: const Key('app_folders.move.new'),
              controller: _name,
              autofocus: targets.isEmpty,
              decoration: InputDecoration(
                hintText: l.newFolderHint,
                prefixIcon: const Icon(Icons.create_new_folder_outlined),
              ),
              onSubmitted: (_) => _finish(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.current != null)
          TextButton(
            key: const Key('app_folders.move.take_out'),
            onPressed: () =>
                Navigator.of(context).pop(const TakeOutOfFolder()),
            child: Text(l.takeOut),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('app_folders.move.confirm'),
          onPressed: target == null || target == widget.current ? null : _finish,
          child: Text(l.move),
        ),
      ],
    );
  }

  void _finish() {
    final target = _target;
    if (target == null || target == widget.current) return;
    Navigator.of(context).pop(MoveIntoFolder(target));
  }
}

/// Asks for a folder's new name. Null when cancelled or unchanged.
Future<String?> showRenameFolderDialog(
  BuildContext context, {
  required String name,
  required AppFolderLabels labels,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(name: name, labels: labels),
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name, required this.labels});
  final String name;
  final AppFolderLabels labels;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.name);

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _target {
    final n = normalizeFolderName(_name.text);
    return n == widget.name ? null : n;
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    return AlertDialog(
      title: Text(l.renameTitle),
      content: TextField(
        key: const Key('app_folders.rename.field'),
        controller: _name,
        autofocus: true,
        onSubmitted: (_) {
          final t = _target;
          if (t != null) Navigator.of(context).pop(t);
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('app_folders.rename.save'),
          onPressed: _target == null
              ? null
              : () => Navigator.of(context).pop(_target),
          child: Text(l.save),
        ),
      ],
    );
  }
}
