import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Channel to the desktop runners (macOS / Windows / Linux). The native side
/// sets the window chrome (title bar) appearance so it inherits the launcher
/// brightness instead of staying a fixed system light.
const MethodChannel _windowChannel = MethodChannel('appplayer/window');

/// Applies the host's effective [brightness] to the platform's system chrome
/// so OS-drawn surfaces inherit the launcher theme:
/// - mobile (iOS / Android): status-bar icons + Android navigation bar
/// - desktop (macOS / Windows / Linux): the native window title bar
///
/// Best-effort and never throws — chrome theming must not crash the app.
Future<void> applyHostBrightness(Brightness brightness) async {
  if (kIsWeb) return;
  final bool isDark = brightness == Brightness.dark;

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      SystemChrome.setSystemUIOverlayStyle(
        isDark ? _darkOverlay : _lightOverlay,
      );
      return;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      try {
        await _windowChannel
            .invokeMethod<void>('setBrightness', <String, Object?>{'dark': isDark});
      } on MissingPluginException {
        // Runner without the handler (older build) — no-op.
      } on PlatformException {
        // Best-effort; ignore native theming failures.
      }
      return;
    case TargetPlatform.fuchsia:
      return;
  }
}

const SystemUiOverlayStyle _darkOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.dark, // iOS: dark scene -> light glyphs
  statusBarIconBrightness: Brightness.light, // Android: light glyphs on dark
  systemNavigationBarColor: Color(0xFF0E0E1A),
  systemNavigationBarIconBrightness: Brightness.light,
);

const SystemUiOverlayStyle _lightOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.light, // iOS: light scene -> dark glyphs
  statusBarIconBrightness: Brightness.dark, // Android: dark glyphs on light
  systemNavigationBarColor: Color(0xFFFFFFFF),
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// Drops into the widget tree above the app and pushes [controller] brightness
/// changes to the platform chrome (initial post-frame + on every change).
class HostChromeBinder extends StatefulWidget {
  const HostChromeBinder({
    super.key,
    required this.controller,
    required this.child,
  });

  final ValueListenable<Brightness> controller;
  final Widget child;

  @override
  State<HostChromeBinder> createState() => _HostChromeBinderState();
}

class _HostChromeBinderState extends State<HostChromeBinder> {
  Brightness? _applied;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_apply);
    // Defer the first apply until the engine + native handler are attached.
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  @override
  void didUpdateWidget(HostChromeBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_apply);
      widget.controller.addListener(_apply);
      _apply();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_apply);
    super.dispose();
  }

  void _apply() {
    final Brightness next = widget.controller.value;
    if (next == _applied) return;
    _applied = next;
    applyHostBrightness(next);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
