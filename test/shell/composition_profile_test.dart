import 'dart:io';

import 'package:appplayer/app/composition_root.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The v1.4 Composition Profile claim, asserted on the REAL composition root.
///
/// Claiming the profile is a single call, and forgetting it fails silently in
/// the worst way: a `view` naming another origin does not error, it renders its
/// fallback. So a bundle composing several devices looks finished on a shell
/// that claims the profile and shows placeholders on one that does not, which
/// reads as a broken bundle rather than a missing capability. Nothing else
/// catches that — every unit test passes either way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the composition root claims the profile', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final tmp = await Directory.systemTemp.createTemp('appplayer_profile');
    addTearDown(() => tmp.delete(recursive: true));

    final ctx = await CompositionRoot.build(
      prefs: await SharedPreferences.getInstance(),
      bundleInstallRootOverride: tmp.path,
    );
    addTearDown(ctx.core.dispose);

    expect(ctx.core.definitionResolver, isNotNull,
        reason: 'without this a `view` fails closed to its fallback');
  });
}
