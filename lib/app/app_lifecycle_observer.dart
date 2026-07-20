import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/widgets.dart';

/// MOD-SHELL-004 — attaches to `WidgetsBinding` to call `core.dispose()`
/// on `AppLifecycleState.detached`.
class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver(this._core, {Logger? logger})
      : _logger = logger ?? NoopLogger();

  final AppPlayerCoreService _core;
  final Logger _logger;

  bool _attached = false;
  bool _disposedByObserver = false;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
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
        if (_disposedByObserver) return;
        _disposedByObserver = true;
        try {
          await _core.dispose();
        } catch (e, st) {
          _logger.logError('app.lifecycle.dispose_failed', e, st);
        }
        break;
    }
  }
}
