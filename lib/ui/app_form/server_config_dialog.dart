import 'dart:math';

import 'package:appplayer_core/appplayer_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';


/// Modal form that creates or edits a [ServerConfig] independently of
/// the launcher's app-form flow.
///
/// Used by dashboard builders that want to register a new MCP server
/// connection on-the-fly instead of picking from an existing list. Pop
/// result: the saved `ServerConfig` on save, `null` on cancel.
class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key, this.initial});

  /// Initial config to edit. `null` opens the dialog in create mode.
  final ServerConfig? initial;

  static Future<ServerConfig?> show(
    BuildContext context, {
    ServerConfig? initial,
  }) {
    return showDialog<ServerConfig>(
      context: context,
      builder: (_) => ServerConfigDialog(initial: initial),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _commandCtrl;
  late final TextEditingController _argsCtrl;
  late final TextEditingController _urlCtrl;
  late TransportType _transportType;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl = TextEditingController(text: init?.name ?? '');
    _descCtrl = TextEditingController(text: init?.description ?? '');
    _transportType = init?.transportType ?? TransportType.stdio;
    final cfg = init?.transportConfig;
    _commandCtrl = TextEditingController(text: cfg?['command'] as String? ?? '');
    final args = cfg?['arguments'];
    _argsCtrl = TextEditingController(
      text: args is List ? args.join(' ') : '',
    );
    _urlCtrl = TextEditingController(text: cfg?['url'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _commandCtrl.dispose();
    _argsCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  String _generateId() {
    final rng = Random.secure();
    return List<int>.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

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
          if (arguments.isNotEmpty) 'arguments': arguments,
        };
      case TransportType.sse:
      case TransportType.streamableHttp:
        return <String, dynamic>{'url': _urlCtrl.text.trim()};
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cfg = ServerConfig(
      id: widget.initial?.id ?? _generateId(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      transportType: _transportType,
      transportConfig: _buildTransportConfig(),
    );
    Navigator.of(context).pop(cfg);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      title: Text(S.get(isEdit ? 'form.edit.connection' : 'form.add.connection')),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: S.get('form.name.required'),
                    hintText: 'My MCP Server',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? S.get('form.name.required.error')
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(labelText: S.get('form.desc')),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.sm),
                _buildTransportFields(),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.get('form.delete.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(S.get(isEdit ? 'form.save' : 'form.add.button')),
        ),
      ],
    );
  }

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
                      hintText: 'npx',
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
                    tooltip: 'Browse',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null &&
                          result.files.single.path != null) {
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
                hintText: '-y @modelcontextprotocol/server-everything',
              ),
            ),
          ],
        );
      case TransportType.sse:
      case TransportType.streamableHttp:
        return TextFormField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            labelText: 'URL *',
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
}
