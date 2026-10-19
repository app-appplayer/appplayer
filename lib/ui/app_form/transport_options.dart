import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/foundation.dart';

/// Whether this host can start a server as its own child process.
///
/// Mobile operating systems do not let an app spawn arbitrary executables,
/// and a browser cannot either, so only desktop offers STDIO.
bool stdioAvailable({TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return false;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
  }
}

/// Transports a new server can be created with on this platform.
List<TransportType> availableTransports(
    {TargetPlatform? platform, bool? isWeb}) {
  final stdio = stdioAvailable(platform: platform, isWeb: isWeb);
  return TransportType.values
      .where((t) => stdio || t != TransportType.stdio)
      .toList();
}

/// Transport a new server starts with: STDIO where it exists, else HTTP.
TransportType defaultTransport({TargetPlatform? platform, bool? isWeb}) {
  return stdioAvailable(platform: platform, isWeb: isWeb)
      ? TransportType.stdio
      : TransportType.streamableHttp;
}

/// Dropdown choices for [current]. A saved server keeps its own transport in
/// the list even when this platform could not create one, so editing it does
/// not break; it just cannot be picked again once changed.
List<TransportType> transportChoices(
  TransportType current, {
  TargetPlatform? platform,
  bool? isWeb,
}) {
  final choices = availableTransports(platform: platform, isWeb: isWeb);
  return choices.contains(current)
      ? choices
      : <TransportType>[current, ...choices];
}
