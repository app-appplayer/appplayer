/// The trust gate (platform spec 19 §9.7).
///
/// Shown instead of a target's own UI when an entry cannot be opened. It names
/// the issuer first: a stranger who scanned a printed thing decides whether to
/// trust it based on who is asking, and that decision has to be possible
/// before anything else renders.
library;

import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';

import '../../entry/entry_controller.dart';

class EntryGateScreen extends StatelessWidget {
  const EntryGateScreen({super.key, required this.blocked});

  final EntryBlocked blocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issuer = blocked.target.issuer;
    final notice = blocked.target.notice;

    return Scaffold(
      appBar: AppBar(title: const Text('Scanned link')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      issuer.verified
                          ? Icons.verified_outlined
                          : Icons.help_outline,
                      color: issuer.verified
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issuer.name.isEmpty
                            ? 'Unidentified issuer'
                            : issuer.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _headline(blocked.rejection),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(_explain(blocked), style: theme.textTheme.bodyMedium),
                if (notice != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(notice.message),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _headline(EntryRejection rejection) {
    switch (rejection) {
      case EntryRejection.notOk:
        return 'This code is no longer active';
      case EntryRejection.stale:
        return 'Please scan again';
      case EntryRejection.accountWallForGuest:
      case EntryRejection.unsupportedTarget:
        return 'This build cannot open it';
      case EntryRejection.identityUnavailable:
        return 'This code needs you signed in';
    }
  }

  String _explain(EntryBlocked blocked) {
    // The reason names what stopped this entry and never suggests another
    // destination — substituting one is what the standard forbids, because a
    // working-looking screen is how a stale binding hides.
    switch (blocked.rejection) {
      case EntryRejection.notOk:
        final reason = blocked.target.reason;
        return reason == null || reason.isEmpty
            ? 'The issuer no longer serves this code.'
            : 'The issuer reported: $reason';
      case EntryRejection.stale:
        return 'The answer for this code expired while it was being opened. '
            'Scanning again gets a current one.';
      case EntryRejection.accountWallForGuest:
        return 'It points at something that needs an account, but it was '
            'issued for anyone to open. Ask the issuer to correct it.';
      case EntryRejection.unsupportedTarget:
        return 'It points at a marketplace item, which this open-source '
            'concept build does not include.';
      case EntryRejection.identityUnavailable:
        return 'The issuer asks for an identified viewer, and this '
            'open-source concept build has no sign-in. Opening it as a guest '
            'would ignore what was asked rather than answer it.';
    }
  }
}
