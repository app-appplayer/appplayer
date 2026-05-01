import 'package:appplayer/app/app_lifecycle_observer.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCore extends Mock implements AppPlayerCoreService {}

class MockLogger extends Mock implements Logger {}

void main() {
  late MockCore core;
  late MockLogger logger;
  late AppLifecycleObserver observer;

  setUp(() {
    core = MockCore();
    logger = MockLogger();
    observer = AppLifecycleObserver(core, logger: logger);
  });

  // TC-LIFE-001: detached triggers core.dispose once (FR-SHELL-005)
  testWidgets('TC-LIFE-001 detached triggers core.dispose once', (tester) async {
    when(() => core.dispose()).thenAnswer((_) async {});

    observer.attach();
    await observer.didChangeAppLifecycleState(AppLifecycleState.detached);

    verify(() => core.dispose()).called(1);
  });

  // TC-LIFE-002: duplicate detached calls only dispose once
  testWidgets('TC-LIFE-002 duplicate detached calls only dispose once',
      (tester) async {
    when(() => core.dispose()).thenAnswer((_) async {});

    observer.attach();
    await observer.didChangeAppLifecycleState(AppLifecycleState.detached);
    await observer.didChangeAppLifecycleState(AppLifecycleState.detached);

    verify(() => core.dispose()).called(1);
  });

  // TC-LIFE-003: paused/resumed do not call core.dispose
  testWidgets('TC-LIFE-003 paused and resumed do not call core.dispose',
      (tester) async {
    observer.attach();
    await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

    verifyNever(() => core.dispose());
  });

  // TC-LIFE-004: core.dispose exception is swallowed
  testWidgets('TC-LIFE-004 core.dispose exception is swallowed',
      (tester) async {
    when(() => core.dispose()).thenThrow(Exception('boom'));

    observer.attach();

    // Should not propagate the exception.
    await observer.didChangeAppLifecycleState(AppLifecycleState.detached);

    verify(() => core.dispose()).called(1);
  });
}
