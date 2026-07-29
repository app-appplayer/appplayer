/// The platform half of deferred entry (platform spec 19 §3.5).
///
/// Android can carry a value across an install through the Play referrer;
/// other platforms cannot, and supplying no source is how that absence is
/// stated — the policy in core turns it into an offer of manual recovery.
library;

import 'dart:io' show Platform;

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Query key an entry link uses when it sends someone to the store.
///
/// The landing page appends `?referrer=entry_code%3D<code>`; the store hands
/// that string back on first launch.
const String kEntryReferrerKey = 'entry_code';

/// Reads the entry code Play carried across the install.
class PlayInstallReferrerSource implements DeferredEntrySource {
  const PlayInstallReferrerSource();

  @override
  Future<String?> pendingCode() async {
    final details = await AndroidPlayInstallReferrer.installReferrer;
    final referrer = details.installReferrer;
    if (referrer == null || referrer.isEmpty) return null;
    return codeFromReferrer(referrer);
  }
}

/// Pull the entry code out of a referrer string.
///
/// The referrer is a query-shaped blob owned by whoever built the store link,
/// so anything else in it is left alone rather than guessed at.
String? codeFromReferrer(String referrer) {
  for (final pair in referrer.split('&')) {
    final i = pair.indexOf('=');
    if (i <= 0) continue;
    if (pair.substring(0, i) != kEntryReferrerKey) continue;
    final raw = pair.substring(i + 1);
    if (raw.isEmpty) return null;
    // Referrers arrive percent-encoded, and a partitioned code space contains
    // slashes — decoding is what keeps `fleet/ABC` from arriving as `fleet%2FABC`.
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }
  return null;
}

/// Only Android offers a mechanism here. Returning null elsewhere is not a
/// gap to hide: it is what makes the host offer a way back instead.
DeferredEntrySource? platformDeferredSource() {
  if (!Platform.isAndroid) return null;
  return const PlayInstallReferrerSource();
}

/// First-launch flag kept next to the app's other preferences.
class PrefsFirstLaunchStore implements FirstLaunchStore {
  const PrefsFirstLaunchStore();

  static const String _key = 'entry.launched.v1';

  @override
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_key) ?? false);
  }

  @override
  Future<void> markLaunched() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
