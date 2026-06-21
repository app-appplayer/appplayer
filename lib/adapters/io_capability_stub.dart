/// No-op io capability for platforms without `dart:io` (web).
///
/// Process / device execution is desktop-only; on web this registers
/// nothing. Signature mirrors `io_capability_io.dart` so callers are
/// platform-agnostic.
library;

import 'package:appplayer_core/appplayer_core.dart';

void registerIoCapability(
  AppPlayerCoreService core, {
  required List<String> allowedRoots,
  List<String> executableAllowlist = const <String>[],
  List<String> roles = const <String>[],
  bool allowShell = false,
}) {}
