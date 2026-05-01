import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default [AppsRegistry] backed by SharedPreferences. The shell supplies
/// the codec ([decode] / [encode]) and the id resolver ([idOf]) so core
/// stays decoupled from the shell's `AppConfig` shape.
///
/// All mutating methods write back to prefs and assign a fresh
/// `List` to [value], which `ValueNotifier` emits to listeners.
class PrefsAppsRegistry<T> extends ValueNotifier<List<T>>
    implements AppsRegistry<T> {
  PrefsAppsRegistry({
    required SharedPreferences prefs,
    required this.storageKey,
    required this.decode,
    required this.encode,
    required this.idOf,
    this.onChanged,
  })  : _prefs = prefs,
        super(List<T>.unmodifiable(decode(prefs.getString(storageKey))));

  final SharedPreferences _prefs;
  final String storageKey;
  final List<T> Function(String? raw) decode;
  final String Function(List<T> apps) encode;
  final String Function(T app) idOf;

  /// Optional shell-side hook invoked after every successful persist.
  /// Used by Standard's legacy `AppsListNotifier.revision` bump so
  /// `prefs`-direct readers (HomeScreen / DashboardScreen) keep working
  /// during the transitional period.
  final void Function()? onChanged;

  @override
  T? byId(String appId) {
    for (final a in value) {
      if (idOf(a) == appId) return a;
    }
    return null;
  }

  @override
  Future<void> add(T app) async {
    final next = List<T>.from(value);
    final i = next.indexWhere((a) => idOf(a) == idOf(app));
    if (i >= 0) {
      next[i] = app;
    } else {
      next.add(app);
    }
    await _persist(next);
  }

  @override
  Future<void> update(T app) async {
    final next = List<T>.from(value);
    final i = next.indexWhere((a) => idOf(a) == idOf(app));
    if (i < 0) return;
    next[i] = app;
    await _persist(next);
  }

  @override
  Future<void> remove(String appId) async {
    final next = value.where((a) => idOf(a) != appId).toList();
    if (next.length == value.length) return;
    await _persist(next);
  }

  /// Re-reads `storageKey` from prefs and emits a fresh list. Use after
  /// an out-of-band writer mutates prefs without going through this
  /// registry (e.g. a different process or migration).
  Future<void> reload() async {
    value = List<T>.unmodifiable(decode(_prefs.getString(storageKey)));
  }

  Future<void> _persist(List<T> apps) async {
    value = List<T>.unmodifiable(apps);
    await _prefs.setString(storageKey, encode(apps));
    onChanged?.call();
  }
}
