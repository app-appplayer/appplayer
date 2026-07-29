/// Opening what an entry resolved to (platform spec 19 §9.4-§9.6).
///
/// Standard opens served targets: it registers the endpoint the way adding a
/// server by hand does, then renders it with the entry attached so the
/// document can read how it was reached.
library;

import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../entry/entry_controller.dart';

class EntryOpenScreen extends StatefulWidget {
  const EntryOpenScreen({super.key, required this.open});

  final EntryOpen open;

  @override
  State<EntryOpenScreen> createState() => _EntryOpenScreenState();
}

class _EntryOpenScreenState extends State<EntryOpenScreen> {
  AppSession? _session;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final core = context.read<AppPlayerCoreService>();
    try {
      // What a target *means* is shared (core `EntryOpener`); only the chrome
      // around it is this tier's. Standard wires no local-node discovery, so
      // such an entry fails visibly rather than dialling something else.
      final session = await EntryOpener(core: core).open(
        target: widget.open.target,
        entry: widget.open.entry,
      );
      if (!mounted) return;
      setState(() => _session = session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      // Naming what could not be opened, rather than a blank failure: an
      // entry that this build cannot serve is a different problem from one
      // that is broken, and only the message tells them apart.
      final message = error is EntryOpenUnsupported
          ? 'This build cannot open it: ${error.reason}'
          : 'Could not open: $error';
      return Scaffold(
        appBar: AppBar(title: const Text('Scanned link')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final session = _session;
    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final issuer = widget.open.entry.issuer;
    final notice = widget.open.entry.notice;

    return Scaffold(
      body: Column(
        children: <Widget>[
          // §9.7 — who is asking, kept visible rather than shown once and
          // dismissed. A scanned code has no address bar: without this the
          // viewer has no way to tell whose surface they are looking at.
          if (issuer != null)
            _IssuerBar(name: issuer.name, verified: issuer.verified),
          if (notice != null)
            MaterialBanner(
              content: Text(notice.message),
              actions: const <Widget>[SizedBox.shrink()],
            ),
          // §9.6 — the requested page was not there. Rendering the app's own
          // start page without saying so would make a stale binding look like
          // a working one.
          if (session.launchRouteMissing)
            const MaterialBanner(
              content: Text(
                'The page this code asked for is no longer in this app. '
                'Showing its start page instead.',
              ),
              actions: <Widget>[SizedBox.shrink()],
            ),
          Expanded(
            child: session.buildWidget(
              context: context,
              onExit: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who is asking, held in the chrome for as long as their surface is shown.
class _IssuerBar extends StatelessWidget {
  const _IssuerBar({required this.name, required this.verified});

  final String name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(
                verified ? Icons.verified_outlined : Icons.help_outline,
                size: 18,
                color: verified
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Unidentified issuer' : name,
                  style: theme.textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Guest sessions are the common case for a scanned code, and
              // saying so is part of the answer: the viewer should know they
              // are anonymous here without having to infer it.
              Text('Guest', style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
