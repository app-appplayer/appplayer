import 'package:appplayer_core/appplayer_core.dart'
    show LogBuffer, LogEntry, LogSource, McpLogLevel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';

/// MOD-UI-LOGS — viewer for `LogBuffer` records. Optional [scopeKey] /
/// [scopeValue] filters entries whose context carries the matching pair
/// (typically `serverId` from a server card menu invocation).
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, this.scopeKey, this.scopeValue, this.title});

  final String? scopeKey;
  final String? scopeValue;
  final String? title;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  McpLogLevel _minLevel = McpLogLevel.debug;
  LogSource? _sourceFilter; // null = all
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _accepts(LogEntry entry) {
    if (entry.level.index < _minLevel.index) return false;
    if (_sourceFilter != null && entry.source != _sourceFilter) return false;
    if (widget.scopeKey != null &&
        entry.context[widget.scopeKey!] != widget.scopeValue) {
      return false;
    }
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (entry.message.toLowerCase().contains(query)) return true;
    return entry.context.entries.any(
      (kv) => kv.value.toString().toLowerCase().contains(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buffer = context.watch<LogBuffer>();
    final filtered = buffer.entries.where(_accepts).toList().reversed.toList();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? S.get('logs.title')),
        actions: [
          IconButton(
            key: const Key('logs.copy'),
            tooltip: S.get('logs.copy'),
            icon: const Icon(Icons.copy_outlined),
            onPressed: filtered.isEmpty
                ? null
                : () async {
                    final text = filtered.reversed
                        .map(_formatEntry)
                        .join('\n');
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(S.get('logs.copied'))),
                    );
                  },
          ),
          IconButton(
            key: const Key('logs.clear'),
            tooltip: S.get('logs.clear'),
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: buffer.entries.isEmpty ? null : buffer.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                DropdownButton<McpLogLevel>(
                  key: const Key('logs.level_filter'),
                  value: _minLevel,
                  items: McpLogLevel.values
                      .map((l) => DropdownMenuItem(
                            value: l,
                            child: Text(l.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _minLevel = v);
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<LogSource?>(
                  key: const Key('logs.source_filter'),
                  value: _sourceFilter,
                  items: <DropdownMenuItem<LogSource?>>[
                    DropdownMenuItem(
                      value: null,
                      child: Text(S.get('logs.source.all')),
                    ),
                    ...LogSource.values.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _sourceFilter = v),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('logs.search'),
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: S.get('logs.search'),
                      prefixIcon: const Icon(Icons.search, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      S.get('logs.empty'),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _LogTile(entry: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatEntry(LogEntry e) {
    final ctx = e.context.isEmpty ? '' : ' ${e.context}';
    final err = e.error == null ? '' : ' err=${e.error}';
    return '[${e.timestamp.toIso8601String()}] '
        '${e.level.name.toUpperCase()} ${e.message}$ctx$err';
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _levelColor(entry.level, cs),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        entry.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '${entry.timestamp.toIso8601String()} · ${entry.level.name}',
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
      childrenPadding:
          const EdgeInsets.fromLTRB(40, 0, 12, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.context.isNotEmpty)
          SelectableText(
            entry.context.entries
                .map((kv) => '${kv.key}: ${kv.value}')
                .join('\n'),
            style: const TextStyle(fontSize: 12),
          ),
        if (entry.error != null) ...[
          const SizedBox(height: 6),
          SelectableText(
            'error: ${entry.error}',
            style: TextStyle(fontSize: 12, color: cs.error),
          ),
        ],
        if (entry.stackTrace != null) ...[
          const SizedBox(height: 6),
          SelectableText(
            entry.stackTrace.toString(),
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ],
    );
  }

  static Color _levelColor(McpLogLevel level, ColorScheme cs) {
    switch (level) {
      case McpLogLevel.debug:
        return cs.onSurfaceVariant;
      case McpLogLevel.info:
      case McpLogLevel.notice:
        return cs.primary;
      case McpLogLevel.warning:
        return cs.tertiary;
      case McpLogLevel.error:
      case McpLogLevel.critical:
      case McpLogLevel.alert:
      case McpLogLevel.emergency:
        return cs.error;
    }
  }
}
