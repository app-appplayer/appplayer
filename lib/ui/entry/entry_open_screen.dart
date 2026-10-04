/// Opening what an entry resolved to (platform spec 19 §9.4-§9.6).
///
/// Standard opens served targets: it registers the endpoint the way adding a
/// server by hand does, then renders it with the entry attached so the
/// document can read how it was reached.
library;

import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Where an `external` target leaves to — such an entry is not a session to
  /// open but a destination to confirm (§9.7).
  Uri? get _leave => entryLeaveDestination(widget.open.target);

  @override
  void initState() {
    super.initState();
    if (widget.open.target.kind != EntryTargetKind.external) _open();
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
    final issuer = widget.open.entry.issuer ?? const EntryIssuer(name: '');
    final notice = widget.open.entry.notice?.message;

    if (widget.open.target.kind == EntryTargetKind.external) {
      final destination = _leave;
      if (destination == null) {
        return EntryFrame(
          issuer: issuer,
          notice: notice,
          showIdentity: false,
          child: const EntryMessage(
            title: 'This code cannot be opened',
            body: <Widget>[
              Text('It points at an address this app does not hand over.'),
            ],
          ),
        );
      }
      return EntryLeaveScreen(
        issuer: issuer,
        destination: destination,
        notice: notice,
        open: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
      );
    }

    final error = _error;
    if (error != null) {
      // Naming what could not be opened, rather than a blank failure: an entry
      // that this build cannot serve is a different problem from one that is
      // broken, and only the message tells them apart.
      final message = error is EntryTargetNotInstalled
          ? 'This app is not installed on this device.'
          : error is EntryOpenUnsupported
              ? 'This build cannot open it: ${error.reason}'
              : 'Could not open: $error';
      return EntryFrame(
        issuer: issuer,
        notice: notice,
        child: EntryMessage(
          title: 'Scanned link',
          body: <Widget>[Text(message)],
        ),
      );
    }

    final session = _session;
    return EntryFrame(
      issuer: issuer,
      notice: notice,
      child: session == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                // §9.6 — the requested page was not there. Rendering the app's
                // own start page without saying so would make a stale binding
                // look like a working one.
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
