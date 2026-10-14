import 'package:flutter/material.dart';

import '../../adapters/blocked_servers.dart';
import '../../l10n/app_strings.dart';

/// The servers the person has blocked, with a way to unblock each
/// (FR-SET-008).
class BlockedServersScreen extends StatefulWidget {
  const BlockedServersScreen({super.key});

  @override
  State<BlockedServersScreen> createState() => _BlockedServersScreenState();
}

class _BlockedServersScreenState extends State<BlockedServersScreen> {
  BlockedServers? _store;
  List<BlockedServer> _items = const <BlockedServer>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await BlockedServers.open();
    if (!mounted) return;
    setState(() {
      _store = store;
      _items = store.all;
      _loaded = true;
    });
  }

  Future<void> _unblock(BlockedServer item) async {
    final store = _store;
    if (store == null) return;
    await store.unblock(item.address);
    if (!mounted) return;
    setState(() => _items = store.all);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.get('blocked.title'))),
      body: !_loaded
          ? const SizedBox.shrink()
          : _items.isEmpty
              ? Center(
                  child: Text(
                    S.get('blocked.empty'),
                    key: const Key('blocked.empty'),
                  ),
                )
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return ListTile(
                      key: Key('blocked.item.${item.address}'),
                      title: Text(item.name.isEmpty ? item.address : item.name),
                      subtitle: item.name.isEmpty ? null : Text(item.address),
                      trailing: TextButton(
                        key: Key('blocked.unblock.${item.address}'),
                        onPressed: () => _unblock(item),
                        child: Text(S.get('blocked.unblock')),
                      ),
                    );
                  },
                ),
    );
  }
}
