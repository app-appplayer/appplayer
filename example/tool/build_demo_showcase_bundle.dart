/// Builds `example/demo_showcase.mbd/` from `apps/demo_ui/test/fixtures/*.json`.
///
/// Philosophy: a bundle is a filesystem snapshot of the server's
/// resource URI responses. Shape translation happens nowhere — the
/// runtime sees identical bytes whether they arrive over an MCP
/// server resource read or through a local `.mbd/ui/**.json` file.
///
/// Layout:
///   demo_showcase.mbd/
///   ├── manifest.json              # manifest only (no ui section)
///   └── ui/
///       ├── app.json             # = ui://app
///       └── pages/
///           ├── layout.json      # = ui://pages/layout
///           ├── display.json     # = ui://pages/display
///           └── ...
///
/// Usage (from repo root):
///   dart run os/appplayer/appplayer/dart/example/tool/build_demo_showcase_bundle.dart
library;

import 'dart:convert';
import 'dart:io';

const _fixturesDir = 'apps/demo_ui/test/fixtures';
const _outputMbd =
    'os/appplayer/appplayer/dart/example/demo_showcase.mbd';

Future<void> main() async {
  final fixtures = Directory(_fixturesDir);
  if (!fixtures.existsSync()) {
    stderr.writeln('Fixtures directory not found: $_fixturesDir');
    exitCode = 66;
    return;
  }
  final appJsonFile = File('$_fixturesDir/app.json');
  if (!appJsonFile.existsSync()) {
    stderr.writeln('Missing $_fixturesDir/app.json');
    exitCode = 66;
    return;
  }

  // Fresh output directory — easier than computing deltas against any
  // prior build.
  final mbdDir = Directory(_outputMbd);
  if (mbdDir.existsSync()) await mbdDir.delete(recursive: true);
  await mbdDir.create(recursive: true);

  // ui/ tree is a 1:1 mirror of the server's resource URI space.
  final uiDir = Directory('${mbdDir.path}/ui');
  final pagesDir = Directory('${uiDir.path}/pages');
  await pagesDir.create(recursive: true);

  await appJsonFile.copy('${uiDir.path}/app.json');

  final pageFiles = fixtures
      .listSync()
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.json') && !f.path.endsWith('app.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in pageFiles) {
    final name = f.path.split(Platform.pathSeparator).last;
    await f.copy('${pagesDir.path}/$name');
  }

  // Manifest is the only typed section the bundle schema requires.
  // The `ui` section is intentionally absent — every page lives as a
  // standalone JSON file under ui/.
  final appJson =
      jsonDecode(await appJsonFile.readAsString()) as Map<String, dynamic>;

  // ui/app/info.json mirrors the manifest fields the launcher reads via
  // `ui://app/info`. Without this file the bundle-backed server has no
  // way to expose metadata, and bundle-installed apps appear in the
  // launcher with an empty name.
  final appInfoDir = Directory('${uiDir.path}/app');
  await appInfoDir.create(recursive: true);
  final appInfo = <String, dynamic>{
    'id': 'com.makemind.examples.demo_showcase',
    'name': '위젯 갤러리',
    'version': (appJson['version'] as String?) ?? '1.0.0',
    'description':
        'MCP UI DSL widget showcase — the same content served by '
            'apps/demo_ui, packaged as a filesystem snapshot under ui/.',
    'icon':
        'https://flutter.github.io/assets-for-api-docs/assets/widgets/falcon.jpg',
    'category': 'developer',
    'publisher': <String, dynamic>{
      'name': 'MakeMind Examples',
      'email': 'examples@makemind.dev',
    },
  };
  await File('${appInfoDir.path}/info.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(appInfo),
    flush: true,
  );

  final manifest = <String, dynamic>{
    'id': appInfo['id'],
    'name': appInfo['name'],
    'version': appInfo['version'],
    'schemaVersion': '1.0.0',
    'type': 'application',
    'entryPoint': 'ui.app',
    'description': appInfo['description'],
    'provider': 'MakeMind',
    'license': 'MIT',
    'icon': appInfo['icon'],
    'category': appInfo['category'],
    'tags': <String>['showcase', 'reference'],
    'publisher': appInfo['publisher'],
  };

  final bundle = <String, dynamic>{
    'schemaVersion': '1.0.0',
    'manifest': manifest,
  };
  await File('${mbdDir.path}/manifest.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(bundle),
    flush: true,
  );

  stdout.writeln(
      'Wrote ${mbdDir.path} (${pageFiles.length} pages)');
}
