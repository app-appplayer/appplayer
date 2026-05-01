import 'package:flutter/foundation.dart';

/// Lightweight global signal that the `apps.v1` list in SharedPreferences
/// changed outside of a push → pop navigation that the home screen can
/// observe (e.g. deletion triggered via `context.go('/')` which replaces
/// the route stack rather than popping back). Any writer that mutates
/// the launcher list calls [markDirty]; [HomeScreen] listens and
/// re-reads on change.
class AppsListNotifier {
  AppsListNotifier._();

  /// Bumps whenever some flow writes `apps.v1`. Home listens and reloads.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void markDirty() {
    revision.value++;
  }
}
