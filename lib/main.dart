import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/app_player_app.dart';
import 'app/composition_root.dart';
import 'app/design_tokens.dart';
import 'l10n/app_strings.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Route every framework and async error to stderr so `flutter run`
    // and monitoring harnesses capture the exact stack.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      stderr.writeln('[FlutterError] ${details.exceptionAsString()}');
      if (details.stack != null) stderr.writeln(details.stack);
    };
    PlatformDispatcher.instance.onError = (Object err, StackTrace st) {
      stderr.writeln('[PlatformDispatcher] $err');
      stderr.writeln(st);
      return true;
    };

    try {
      final ctx = await CompositionRoot.build();
      runApp(AppPlayerApp(ctx: ctx));
    } catch (e, st) {
      stderr.writeln('[Bootstrap] $e');
      stderr.writeln(st);
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'appplayer'),
      );
      runApp(_FatalErrorApp(error: e, stack: st));
    }
  }, (err, st) {
    stderr.writeln('[Zone] $err');
    stderr.writeln(st);
  });
}

class _FatalErrorApp extends StatelessWidget {
  const _FatalErrorApp({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.error_outline, size: AppIconSizes.xl),
              const SizedBox(height: AppSpacing.sm),
              Text(S.get('app.init.fail')),
              const SizedBox(height: AppSpacing.sm),
              SelectableText('$error'),
            ],
          ),
        ),
      ),
    );
  }
}
