// Every declared widget, drawn in this app.
//
// The shipped bundle covers 108 of the 158 widgets the spec declares, so 50
// of them had never appeared on an AppPlayer screen. The runtime has its own
// matrix, but it runs in the runtime package: its own pubspec, its own
// Material defaults, its own fonts and icon set. "The runtime can draw it"
// and "this app can draw it" are different claims, and only the second one
// is what a user sees.
//
// So: enumerate the registry, take each widget's own spec examples, and pump
// them here. A widget passes only if the frame carries no FlutterError **and**
// no error widget — the renderer paints a red box instead of throwing, so a
// suite that only watches for exceptions reports a clean run over a screen
// full of errors.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// §2.11 — raised by an action, never placed in the tree.
const _dialogSurfaces = <String>{
  'alertDialog', 'simpleDialog', 'customDialog', 'bottomSheet', 'snackBar',
};

/// Only meaningful inside a particular parent (§2.15).
const _needsFlexParent = <String>{'expanded', 'flexible', 'spacer'};
const _needsStackParent = <String>{'positioned'};

const _errorMarkers = <String>[
  'Unknown widget type:',
  'Error rendering',
  'Widget type is required',
];

class _Widget {
  _Widget(this.type, this.examples, this.minimal);
  final String type;
  final List<Map<String, dynamic>> examples;

  /// The smallest legal document for this widget, built from the properties
  /// the registry marks required. Widgets the spec ships no example for are
  /// drawn from this — `{"type": x}` alone would be missing whatever the
  /// widget cannot do without, and would fail for the harness's reasons
  /// rather than the widget's.
  final Map<String, dynamic> minimal;
}

final List<_Widget> _registry = _loadRegistry();

void main() {
  test('the registry still declares every widget this suite covers', () {
    expect(_registry.length, greaterThanOrEqualTo(158),
        reason: 'registry shrank to ${_registry.length} widgets — a suite '
            'that covers less by running less is the failure this guards');
    final noExample =
        _registry.where((w) => w.examples.isEmpty).map((w) => w.type).toList();
    // Widgets without a positive example are drawn from their type alone,
    // which is still a screen; this only reports how many rely on that.
    // ignore: avoid_print
    if (noExample.isNotEmpty) {
      stderr.writeln('NOTE: ${noExample.length} widget(s) have no positive '
          'example and are drawn from their type alone');
    }
  });

  for (final widget in _registry) {
    testWidgets('${widget.type} draws in AppPlayer', (tester) async {
      final documents =
          widget.examples.isEmpty ? [widget.minimal] : widget.examples;

      final failures = <String>[];
      for (var i = 0; i < documents.length; i++) {
        final problem = await _draw(tester, widget.type, documents[i]);
        if (problem != null) failures.add('example_$i: $problem');
      }
      expect(failures, isEmpty,
          reason: '${widget.type} did not draw:\n  - ${failures.join("\n  - ")}');
    });
  }
}

Future<String?> _draw(
  WidgetTester tester,
  String type,
  Map<String, dynamic> fragment,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exception.toString();
    // This engine rejects the bundled Material ink shader.
    if (text.contains('ink_sparkle.frag')) return;
    // flutter_test answers every real request with 400.
    if (text.contains('HTTP request failed, statusCode: 400')) return;
    errors.add(details);
  };

  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final runtime = MCPUIRuntime();
  String? failure;
  try {
    await runtime.initialize(
      _asPage(type, fragment),
      useCache: false,
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'stub'},
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));
  } catch (e) {
    failure = 'threw while building: $e';
  }
  FlutterError.onError = previous;

  if (failure == null) {
    for (final marker in _errorMarkers) {
      final found = find.textContaining(marker);
      if (!tester.any(found)) continue;
      failure = 'error widget drawn: '
          '${tester.widgetList<Text>(found).first.data ?? marker}';
      break;
    }
  }
  await runtime.dispose();

  if (failure == null && errors.isNotEmpty) {
    failure = 'FlutterError: ${errors.first.exceptionAsString()}';
  }
  return failure;
}

Map<String, dynamic> _asPage(String type, Map<String, dynamic> fragment) {
  final kind = fragment['type'];
  if (kind == 'page' || kind == 'application') return fragment;

  if (_dialogSurfaces.contains(type)) {
    return <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'button',
        'label': 'open',
        'onTap': <String, dynamic>{'type': 'dialog', 'dialog': fragment},
      },
    };
  }
  if (_needsFlexParent.contains(type)) {
    return <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'linear',
        'direction': 'horizontal',
        'children': <Object>[fragment],
      },
    };
  }
  if (_needsStackParent.contains(type)) {
    return <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'stack',
        'children': <Object>[fragment],
      },
    };
  }
  return <String, dynamic>{'type': 'page', 'content': fragment};
}

List<_Widget> _loadRegistry() {
  final dir = Directory(
    p.join(_findRepoRoot(), 'specs', 'mcp_ui_dsl', 'spec', '1.4', 'widgets'),
  );
  final out = <_Widget>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.yaml')) continue;
    final doc = loadYaml(entity.readAsStringSync());
    if (doc is! YamlMap) continue;
    final type = doc['type'] as String?;
    if (type == null) continue;

    final examples = <Map<String, dynamic>>[];
    final raw = doc['examples'];
    if (raw is YamlList) {
      for (final e in raw) {
        final example = e as YamlMap;
        // The registry marks its deliberately-invalid examples; drawing one
        // is not the question this suite asks.
        if (example['expect']?.toString() == 'validation_error') continue;
        final dsl = example['dsl'];
        if (dsl is! String) continue;
        try {
          final decoded = jsonDecode(dsl);
          if (decoded is Map<String, dynamic>) examples.add(decoded);
        } on FormatException {
          // `validate_examples` grades malformed examples.
        }
      }
    }
    out.add(_Widget(type, examples, _minimalDoc(type, doc['properties'])));
  }
  out.sort((a, b) => a.type.compareTo(b.type));
  return out;
}


/// Builds `{type}` plus a plausible value for every property the registry
/// marks required.
Map<String, dynamic> _minimalDoc(String type, Object? properties) {
  final doc = <String, dynamic>{'type': type};
  if (properties is! YamlMap) return doc;
  for (final entry in properties.entries) {
    final prop = entry.value;
    if (prop is! YamlMap || prop['required'] != true) continue;
    final value = _sample(prop['type']?.toString() ?? 'string', prop);
    if (value != null) doc[entry.key as String] = value;
  }
  return doc;
}

Object? _sample(String declared, YamlMap prop) {
  final t = declared.split('|').first.trim();
  final values = prop['enum'];
  if (values is YamlList && values.isNotEmpty) return values.first.toString();
  if (t.startsWith('array<')) {
    final element = _bare(t.substring(6, t.length - 1));
    return element == null ? null : <Object>[element];
  }
  return _bare(t);
}

Object? _bare(String t) {
  switch (t) {
    case 'string':
      return 'sample';
    case 'number':
    case 'integer':
      return 1;
    case 'boolean':
      return true;
    case 'object':
      return <String, dynamic>{};
    case 'Widget':
      return <String, dynamic>{'type': 'text', 'content': 'sample'};
    case 'Action':
      return <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': 'sample',
        'value': 1,
      };
    case 'Color':
      return '#FF0000';
    case 'Dimension':
      return 24;
    case 'AssetRef':
      // §6.12: a reference carries a scheme or the `assets/` prefix.
      return 'assets/sample.png';
    case 'IconRef':
      return 'home';
    case 'Alignment':
      return 'center';
    case 'DefinitionSource':
      return 'ui://pages/sample';
    case 'binding':
      return '{{sample}}';
    default:
      // A named element type with no modelling rule (Point, Tab, …).
      return <String, dynamic>{};
  }
}

String _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 12; i++) {
    if (Directory(p.join(dir.path, 'specs', 'mcp_ui_dsl')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('repo root not found from ${Directory.current.path}');
}
