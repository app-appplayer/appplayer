import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Whether the Debug MCP endpoint can be switched on in this build.
///
/// The endpoint hands out screenshots and injects input to whoever reaches
/// its loopback port, so it is a development tool: available on desktop
/// builds, and on mobile only in debug and profile builds. A mobile release
/// build — the one people install from a store — has neither the setting nor
/// the endpoint, whatever a stored preference says.
bool get debugMcpAvailable => debugMcpAvailableOn(
      isWeb: kIsWeb,
      isMobile: !kIsWeb && (Platform.isAndroid || Platform.isIOS),
      isRelease: kReleaseMode,
    );

/// [debugMcpAvailable] for explicit inputs, so the rule can be tested.
bool debugMcpAvailableOn({
  required bool isWeb,
  required bool isMobile,
  required bool isRelease,
}) {
  if (isWeb) return false;
  if (isMobile && isRelease) return false;
  return true;
}
