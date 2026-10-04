import 'package:appplayer_core/appplayer_core.dart' show AppMetadata;
import 'package:appplayer/app/app_metadata_merge.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

AppMetadata _announced(String name) => AppMetadata(
      appId: 'shop',
      sourceKind: 'server',
      name: name,
      version: '1.0.0',
    );

void main() {
  group('tile name (FR-ADAPT-006)', () {
    test('a given name stays: two shops on one bundle stay two tiles', () {
      final riverside = AppConfig(
          id: 'shop.riverside',
          name: 'Counter (riverside)',
          type: AppType.server);
      final hilltop = AppConfig(
          id: 'shop.hilltop', name: 'Counter (hilltop)', type: AppType.server);
      expect(mergeAppMetadata(riverside, _announced('Counter')).name,
          'Counter (riverside)');
      expect(mergeAppMetadata(hilltop, _announced('Counter')).name,
          'Counter (hilltop)');
    });

    test('a name filled in automatically gives way to the announced one', () {
      final auto = AppConfig(
        id: 'srv-1',
        name: 'localhost',
        nameFromSource: true,
        type: AppType.server,
      );
      final merged = mergeAppMetadata(auto, _announced('Counter'));
      expect(merged.name, 'Counter');
      expect(merged.nameFromSource, isTrue,
          reason: 'a later announcement still applies');
    });

    test('an entry from before the mark: automatic only when named by its id',
        () {
      final legacy = AppConfig(
          id: 'com.example.app', name: 'com.example.app', type: AppType.bundle);
      expect(mergeAppMetadata(legacy, _announced('Example')).name, 'Example');
    });

    test('an empty announcement keeps the name', () {
      final auto = AppConfig(
        id: 'srv-1',
        name: 'localhost',
        nameFromSource: true,
        type: AppType.server,
      );
      expect(mergeAppMetadata(auto, _announced('  ')).name, 'localhost');
    });

    test('the mark survives storage; a given name stores none', () {
      final auto = AppConfig(
        id: 'a',
        name: 'host',
        nameFromSource: true,
        type: AppType.server,
      );
      expect(AppConfig.fromJson(auto.toJson()).nameFromSource, isTrue);
      final given = AppConfig(id: 'b', name: 'Mine', type: AppType.server);
      expect(given.toJson().containsKey('nameFromSource'), isFalse);
      expect(AppConfig.fromJson(given.toJson()).nameFromSource, isFalse);
    });
  });
}
