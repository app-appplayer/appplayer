/// One place an entry outcome turns into a screen.
///
/// A scan and an intercepted link are the same entry (§9.2), so they must not
/// reach two copies of this switch — the copy that gets forgotten is how the
/// two paths drift apart.
library;

import 'package:go_router/go_router.dart';

import 'entry_controller.dart';

/// Route names, kept next to the routing so a rename cannot miss a caller.
class EntryRoutes {
  EntryRoutes._();

  static const String blocked = '/entry/blocked';
  static const String open = '/entry/open';
  static const String scan = '/entry/scan';
}

/// Put [outcome] on screen. Returns whether anything was shown — a link that
/// is not ours produces no screen, and the caller may want to say so.
bool routeEntryOutcome(GoRouter router, EntryOutcome outcome) {
  switch (outcome) {
    case EntryBlocked():
      // The gate replaces the target's UI and never falls through to another
      // destination (§4.3).
      router.push(EntryRoutes.blocked, extra: outcome);
      return true;
    case EntryOpen():
      router.push(EntryRoutes.open, extra: outcome);
      return true;
    case EntryNotForUs():
      return false;
  }
}
