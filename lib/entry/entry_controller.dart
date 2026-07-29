/// Turning an incoming link into an opened app (platform spec 19 §9).
///
/// Standard is the **concept host**: it claims a demo domain and implements
/// the guest-reachable target kinds. That is not a reduced feature set — it is
/// exactly the guest path the standard defines, since a guest cannot pass an
/// account wall and therefore never needs an account-gated target. Entries
/// that do resolve to one are reported, never quietly redirected.
library;

import 'package:appplayer_core/appplayer_core.dart';

/// What the host should put on screen.
sealed class EntryOutcome {
  const EntryOutcome();
}

/// Not an entry link at all — the host does whatever it normally does with a
/// URL. Reported rather than swallowed so a mis-typed claim is debuggable.
class EntryNotForUs extends EntryOutcome {
  const EntryNotForUs(this.rejection);
  final EntryLinkRejection rejection;
}

/// Open this. [entry] is the slice the opened definition may read.
class EntryOpen extends EntryOutcome {
  const EntryOpen({
    required this.target,
    required this.entry,
    required this.identityRequired,
  });

  final EntryTargetRef target;
  final EntryContext entry;

  /// The viewer must be identified before anything renders (§4.2 `required`).
  final bool identityRequired;
}

/// Render the trust gate: who was asking, and why this stopped.
class EntryBlocked extends EntryOutcome {
  const EntryBlocked({required this.target, required this.rejection});
  final EntryTarget target;
  final EntryRejection rejection;
}

/// Runs an acquired link through the standard's rules.
///
/// Deliberately free of Flutter and of the link plugin: every acquisition path
/// (an intercepted link, a scanner, a deferred entry recovered after an
/// install) hands a URL to the same method (§9.2), and this stays testable
/// without a device.
class EntryController {
  EntryController({
    required EntryPipeline pipeline,
    required Set<String> claimedHosts,
    String pathPrefix = '/e',
  })  : _pipeline = pipeline,
        _claimedHosts = claimedHosts,
        _pathPrefix = pathPrefix;

  final EntryPipeline _pipeline;
  final Set<String> _claimedHosts;
  final String _pathPrefix;

  /// Target kinds this build can actually open. Standard ships no
  /// marketplace, so `bundle` and `listing` are absent — an entry naming one
  /// is surfaced as unsupported instead of being silently redirected.
  static const Set<EntryTargetKind> conceptTargets = <EntryTargetKind>{
    EntryTargetKind.server,
    EntryTargetKind.localServer,
    EntryTargetKind.external,
  };

  Future<EntryOutcome> handle(Uri uri, {required String locale}) async {
    final link = EntryLink.parse(
      uri,
      claimedHosts: _claimedHosts,
      pathPrefix: _pathPrefix,
    );
    if (!link.isEntry) {
      return EntryNotForUs(link.rejection!);
    }

    final decision = await _pipeline.decide(link.code!, locale: locale);
    if (!decision.canOpen) {
      return EntryBlocked(
        target: decision.target,
        rejection: decision.rejection!,
      );
    }

    final target = decision.target;
    return EntryOpen(
      target: target.target!,
      entry: target.toEntryContext(),
      identityRequired: decision.identityRequired,
    );
  }
}
