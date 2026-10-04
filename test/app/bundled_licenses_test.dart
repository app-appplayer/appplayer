// The notice lists this app registers at start (appplayer_core FR-LIC-004),
// read the way the app reads them. A list registration would refuse fails
// here, not on the licenses page of the platform nobody happened to open.
import 'dart:io';

import 'package:appplayer_core/appplayer_core.dart' show OpenSourceLicenses;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final list in ['apple.json', 'android.json']) {
    test('$list reads as registered', () {
      final entries = OpenSourceLicenses.parseBundled(
          File('assets/licenses/$list').readAsStringSync(),
          from: list);
      expect(entries, isNotEmpty);
    });
  }
}
