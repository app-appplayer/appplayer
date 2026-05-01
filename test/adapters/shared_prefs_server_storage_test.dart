import 'package:appplayer/adapters/shared_prefs_server_storage.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ServerConfig _cfg(String id, {String name = 'srv', bool fav = false}) {
  return ServerConfig(
    id: id,
    name: name,
    description: '',
    transportType: TransportType.stdio,
    transportConfig: const {'command': 'echo'},
    isFavorite: fav,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsServerStorage', () {
    test('TC-PRFSRV-001 empty getServers returns []', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      expect(await storage.getServers(), isEmpty);
    });

    test('TC-PRFSRV-002 saveServer + getServers', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      final c = _cfg('a');
      await storage.saveServer(c);
      final list = await storage.getServers();
      expect(list, hasLength(1));
      expect(list.first.id, 'a');
      // Persisted
      expect(prefs.getString(SharedPrefsServerStorage.storageKey), isNotNull);
    });

    test('TC-PRFSRV-003 saveServer is idempotent upsert', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      await storage.saveServer(_cfg('a', name: 'old'));
      await storage.saveServer(_cfg('a', name: 'new'));
      final list = await storage.getServers();
      expect(list, hasLength(1));
      expect(list.first.name, 'new');
    });

    test('TC-PRFSRV-004 getById existing', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      await storage.saveServer(_cfg('a'));
      expect((await storage.getById('a'))?.id, 'a');
    });

    test('TC-PRFSRV-005 getById missing returns null', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      expect(await storage.getById('x'), isNull);
    });

    test('TC-PRFSRV-006 deleteServer removes', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      await storage.saveServer(_cfg('a'));
      await storage.deleteServer('a');
      expect(await storage.getServers(), isEmpty);
    });

    test('TC-PRFSRV-007 deleteServer missing no-op', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      // Must not throw
      await storage.deleteServer('missing');
      expect(await storage.getServers(), isEmpty);
    });

    test('TC-PRFSRV-008 updateLastConnected', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      await storage.saveServer(_cfg('a'));
      final t = DateTime.utc(2026, 4, 16);
      await storage.updateLastConnected('a', t);
      expect((await storage.getById('a'))?.lastConnectedAt, t);
    });

    test('TC-PRFSRV-009 updateLastConnected missing no-op', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      await storage.updateLastConnected('x', DateTime.now());
      expect(await storage.getServers(), isEmpty);
    });

    test('TC-PRFSRV-010 toggleFavorite', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      await storage.saveServer(_cfg('a'));
      await storage.toggleFavorite('a');
      expect((await storage.getById('a'))?.isFavorite, isTrue);
      await storage.toggleFavorite('a');
      expect((await storage.getById('a'))?.isFavorite, isFalse);
    });

    test('TC-PRFSRV-011 corrupted json falls back to []', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsServerStorage.storageKey: '{invalid',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      expect(await storage.getServers(), isEmpty);
    });

    test('TC-PRFSRV-012 clearAll', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsServerStorage(prefs);
      await storage.saveServer(_cfg('a'));
      await storage.saveServer(_cfg('b'));
      await storage.clearAll();
      expect(await storage.getServers(), isEmpty);
      expect(prefs.containsKey(SharedPrefsServerStorage.storageKey), isFalse);
    });
  });
}
