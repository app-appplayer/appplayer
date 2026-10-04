import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// MOD-SHELL-004 — attaches to `WidgetsBinding` to call `core.dispose()`
/// on `AppLifecycleState.detached`.
class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver(
    this._core, {
    Logger? logger,
    Stream<ProcessSignal>? terminate,
    void Function(int code)? exitProcess,
  })  : _logger = logger ?? NoopLogger(),
        _terminate = terminate ?? _sigterm(),
        _exit = exitProcess ?? exit;

  final AppPlayerCoreService _core;
  final Logger _logger;
  final Stream<ProcessSignal>? _terminate;
  final void Function(int code) _exit;
  StreamSubscription<ProcessSignal>? _terminateSub;

  bool _attached = false;
  bool _disposedByObserver = false;

  /// `SIGTERM` where the platform delivers it to Dart (macOS · Linux).
  static Stream<ProcessSignal>? _sigterm() =>
      kIsWeb || Platform.isWindows ? null : ProcessSignal.sigterm.watch();

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    // Asked to end from outside (`kill`): close what this host started, then
    // go. A stdio server is this host's child process; left open it outlives
    // the host and keeps running on its own.
    _terminateSub = _terminate?.listen((_) async {
      await _shutDown();
      _exit(0);
    });
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_terminateSub?.cancel());
    _terminateSub = null;
    _attached = false;
  }

  /// A desktop quit (the menu, the last window) asks here before the process
  /// ends; `detached` is not delivered on that way out, so the core is closed
  /// here and the quit goes ahead once it is.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _shutDown();
    return AppExitResponse.exit;
  }

  Future<void> _shutDown() async {
    if (_disposedByObserver) return;
    _disposedByObserver = true;
    try {
      await _core.dispose();
    } catch (e, st) {
      _logger.logError('app.lifecycle.dispose_failed', e, st);
    }
  }

  @override
  void didHaveMemoryPressure() {
    // Route the OS memory-pressure signal to the core so it can reclaim
    // re-creatable memory (caches, inactive runtimes) — FR-MEM.
    _core.onLifecyclePhase(AppLifecyclePhase.memoryPressure);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        _logger.info('app.lifecycle.resumed');
        await _core.onLifecyclePhase(AppLifecyclePhase.foreground);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _logger.info('app.lifecycle.paused');
        // Both map to background: the process may be suspended, so the core
        // applies its BackgroundPolicy (pause / keepAlive) to connections.
        await _core.onLifecyclePhase(AppLifecyclePhase.background);
        break;
      case AppLifecycleState.inactive:
        await _core.onLifecyclePhase(AppLifecyclePhase.inactive);
        break;
      case AppLifecycleState.detached:
        await _shutDown();
        break;
    }
  }
}
