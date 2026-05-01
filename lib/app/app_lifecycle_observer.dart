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
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        _logger.info('app.lifecycle.resumed');
        break;
      case AppLifecycleState.paused:
        _logger.info('app.lifecycle.paused');
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
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }
}
