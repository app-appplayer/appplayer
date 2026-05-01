import 'package:appplayer/adapters/prefs_apps_registry.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppConfig _server(String id, {String name = 'srv'}) {
  return AppConfig(
    id: id,
    name: name,
    type: AppType.server,
    serverConfigId: id,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PrefsAppsRegistry', () {
    test('TC-REG-001 starts empty when prefs key absent', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      expect(reg.value, isEmpty);
    });

    test('TC-REG-002 hydrates from existing prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'apps.v1',
        AppConfig.encodeList([_server('a'), _server('b')]),
      );
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      expect(reg.value.map((a) => a.id), ['a', 'b']);
    });

    test('TC-REG-003 add appends and persists + notifies', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      var notifications = 0;
      reg.addListener(() => notifications++);

      await reg.add(_server('a'));
      await reg.add(_server('b'));

      expect(reg.value.map((a) => a.id), ['a', 'b']);
      expect(notifications, 2);
      expect(
        AppConfig.decodeList(prefs.getString('apps.v1')).map((a) => a.id),
        ['a', 'b'],
      );
    });

    test('TC-REG-004 add with same id replaces existing', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      await reg.add(_server('a', name: 'first'));
      await reg.add(_server('a', name: 'second'));

      expect(reg.value, hasLength(1));
      expect(reg.value.first.name, 'second');
    });

    test('TC-REG-005 update replaces matching entry', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      await reg.add(_server('a', name: 'old'));
      await reg.update(_server('a', name: 'new'));

      expect(reg.value.first.name, 'new');
    });

    test('TC-REG-006 update is no-op when id not found', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      await reg.add(_server('a'));
      await reg.update(_server('zzz'));

      expect(reg.value, hasLength(1));
      expect(reg.value.first.id, 'a');
    });

    test('TC-REG-007 remove drops the matching entry', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      await reg.add(_server('a'));
      await reg.add(_server('b'));
      await reg.remove('a');

      expect(reg.value.map((a) => a.id), ['b']);
    });

    test('TC-REG-008 remove of unknown id is silent', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      await reg.add(_server('a'));
      var notifications = 0;
      reg.addListener(() => notifications++);

      await reg.remove('zzz');

      expect(reg.value.map((a) => a.id), ['a']);
      expect(notifications, 0);
    });

    test('TC-REG-009 byId returns matching entry or null', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      await reg.add(_server('a'));
      expect(reg.byId('a'), isNotNull);
      expect(reg.byId('zzz'), isNull);
    });

    test('TC-REG-010 onChanged fires after every successful persist',
        () async {
      final prefs = await SharedPreferences.getInstance();
      var changes = 0;
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
        onChanged: () => changes++,
      );

      await reg.add(_server('a'));
      await reg.update(_server('a', name: 'updated'));
      await reg.remove('a');
      await reg.remove('zzz'); // no-op — should NOT increment

      expect(changes, 3);
    });

    test('TC-REG-011 reload re-emits the persisted list', () async {
      final prefs = await SharedPreferences.getInstance();
      final reg = PrefsAppsRegistry<AppConfig>(
        prefs: prefs,
        storageKey: 'apps.v1',
        decode: AppConfig.decodeList,
        encode: AppConfig.encodeList,
        idOf: (a) => a.id,
      );
      await prefs.setString(
        'apps.v1',
        AppConfig.encodeList([_server('out-of-band')]),
      );
      var notifications = 0;
      reg.addListener(() => notifications++);

      await reg.reload();

      expect(reg.value.map((a) => a.id), ['out-of-band']);
      expect(notifications, 1);
    });
  });
}
