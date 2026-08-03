// Every screen of the shipped bundle, drawn.
//
// The runtime has a widget matrix (spec examples, one widget at a time) and a
// demo_ui page audit (fixtures, through `MCPUIRuntime` directly). Neither goes
// through AppPlayer: the bundle is never read from disk, the manifest is never
// parsed, `bundle://` is never resolved, and the pages are never composed the
// way a shipped app composes them.
//
// This does. `example/demo_showcase.mbd` is the bundle that ships with
// Standard; each of its 15 pages is loaded through the same adapter the host
// uses and pumped into a real widget tree. A page passes only if the frame
// carries no FlutterError **and** no error widget — the renderer reports a
// broken widget by painting a red box, which is a successful build as far as
// the framework is concerned, so asserting on exceptions alone sees nothing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:path/path.dart' as p;

/// Markers the renderer paints instead of throwing.
const _errorMarkers = <String>[
  'Unknown widget type:',
  'Error rendering',
  'Widget type is required',
];

void main() {
  late final Directory pagesDir;

  setUpAll(() {
    final root = _findPackageRoot();
    pagesDir = Directory(
      p.join(root, 'example', 'demo_showcase.mbd', 'ui', 'pages'),
    );
    expect(pagesDir.existsSync(), isTrue,
        reason: 'shipped bundle not found at ${pagesDir.path}');
  });

  test('the shipped bundle still has every page this suite covers', () {
    final found = pagesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .length;
    // A bundle that lost pages would make this suite pass by covering less.
    expect(found, greaterThanOrEqualTo(15),
        reason: 'bundle shrank to $found pages');
  });

  for (final name in const [
    'advanced', 'charts', 'client-resources', 'dev', 'dialog', 'display',
    'form', 'input', 'interactive', 'layout', 'list', 'media', 'navigation',
    'realtime', 'scroll',
  ]) {
    testWidgets('showcase page "$name" draws', (tester) async {
      final file = File(p.join(pagesDir.path, '$name.json'));
      expect(file.existsSync(), isTrue, reason: 'missing page $name.json');
      final page = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exception.toString();
        // This engine rejects the bundled Material ink shader; it fires on
        // any tap surface and has nothing to do with the page.
        if (text.contains('ink_sparkle.frag')) return;
        // `flutter_test` answers every real request with 400, so a page
        // naming a remote image fails on the network rather than on itself.
        if (text.contains('HTTP request failed, statusCode: 400')) return;
        errors.add(details);
      };

      // A desktop viewport: these pages are written for one, and a phone-sized
      // surface would report overflow that the shipped app never shows.
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final runtime = MCPUIRuntime();
      String? failure;
      try {
        await runtime.initialize(page, useCache: false);
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: runtime.buildUI())),
        );
        // A second frame so post-layout failures (overflow, viewport
        // constraints) surface — §2.15's whole subject.
        await tester.pump(const Duration(milliseconds: 50));
      } catch (e) {
        failure = 'threw while building: $e';
      }
      FlutterError.onError = previous;

      failure ??= _drawnError(tester);
      await runtime.dispose();

      if (errors.isNotEmpty) {
        failure ??= 'FlutterError: ${errors.first.exceptionAsString()}';
      }
      expect(failure, isNull, reason: 'page "$name" did not draw: $failure');
    });
  }
}

String? _drawnError(WidgetTester tester) {
  for (final marker in _errorMarkers) {
    final found = find.textContaining(marker);
    if (!tester.any(found)) continue;
    return 'error widget drawn: '
        '${tester.widgetList<Text>(found).first.data ?? marker}';
  }
  return null;
}

String _findPackageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(dir.path, 'example', 'demo_showcase.mbd'))
            .existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('package root not found from ${Directory.current.path}');
}
