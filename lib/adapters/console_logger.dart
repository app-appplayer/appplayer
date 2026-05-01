import 'dart:convert';
import 'dart:developer' as developer;

import 'package:appplayer_core/appplayer_core.dart';

/// MOD-ADAPT-004 — Logger backed by `dart:developer.log`.
class ConsoleLogger extends Logger {
  ConsoleLogger({this.minLevel = LogLevel.info});

  LogLevel minLevel;

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    var line = message;
    if (context != null && context.isNotEmpty) {
      try {
        line = '$message ${jsonEncode(_sanitize(context))}';
      } catch (_) {
        line = message;
      }
    }

    developer.log(
      line,
      name: 'AppPlayer',
      level: _severity(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> ctx) {
    return ctx.map((k, v) {
      if (v == null || v is num || v is bool || v is String) {
        return MapEntry(k, v);
      }
      if (v is Map || v is List) {
        return MapEntry(k, v);
      }
      return MapEntry(k, v.toString());
    });
  }

  static int _severity(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warn:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
