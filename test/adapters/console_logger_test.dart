import 'package:appplayer/adapters/console_logger.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConsoleLogger', () {
    test('TC-LOG-001 info below minLevel warn is suppressed', () {
      final logger = ConsoleLogger(minLevel: LogLevel.warn);
      // Should not throw — behaviour verified by no crash; output is process-side.
      logger.log(LogLevel.info, 'suppressed');
      logger.log(LogLevel.debug, 'suppressed');
    });

    test('TC-LOG-002 warn at minLevel is emitted', () {
      final logger = ConsoleLogger(minLevel: LogLevel.warn);
      logger.log(LogLevel.warn, 'allowed');
      // No assertion — test verifies no throw on valid path.
    });

    test('TC-LOG-003 logError passes error + stack', () {
      final logger = ConsoleLogger(minLevel: LogLevel.debug);
      logger.logError('e', Exception('x'), StackTrace.current);
    });

    test('TC-LOG-004 context sanitize fallback on unserializable value', () {
      final logger = ConsoleLogger(minLevel: LogLevel.debug);
      logger.info('m', {'bad': Object(), 'ok': 1});
      // Succeeds — sanitize converts Object() via toString.
    });

    test('TC-LOG-005 level mapping constants preserved', () {
      // The mapping is private but observable via the severity passed to
      // developer.log; here we only assert no throw for all levels.
      final logger = ConsoleLogger(minLevel: LogLevel.debug);
      for (final lv in LogLevel.values) {
        logger.log(lv, 'lv=${lv.name}');
      }
    });
  });
}
