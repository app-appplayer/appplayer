import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The vendored copy must be byte-identical to the recipe it came from.
///
/// This tier vendors `host_media` rather than path-depending on it, because it
/// ships from a public repository and a path dependency reaching outside that
/// repository would not resolve for whoever checks it out. The cost of that
/// choice is drift, and it is not hypothetical: the very first change to the
/// recipe after vendoring (asset bytes reaching the players, so a `bundle://`
/// sound plays the way a `bundle://` image already draws) left this copy
/// behind, and the tier stopped compiling.
///
/// A compile error was the lucky outcome. The dangerous version of this drift
/// is one that still compiles — the copy keeps an older behaviour and this tier
/// quietly does something different from every other one.
void main() {
  const recipeDir = '../../../core/brain_kernel/recipes/host_media/lib/src';
  const vendorDir = 'lib/adapters/host_media';

  test('vendored host_media matches the recipe', () {
    if (!Directory(recipeDir).existsSync()) {
      // A standalone checkout of the public repository has no recipe tree next
      // to it. Nothing to compare against, and nothing to fail: the copy is
      // the source there.
      return;
    }

    // Every source file, not a named one: the copy fell behind the first time
    // because a new file appeared beside the one this test knew about.
    final recipeFiles = Directory(recipeDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.uri.pathSegments.last)
        .toList()
      ..sort();
    // The web surface is consumed through the recipe's own conditional export
    // and is not vendored; everything else must be.
    final expected = recipeFiles.where((n) => !n.startsWith('web_surface'));

    for (final name in expected) {
      final vendored = File('$vendorDir/$name');
      expect(vendored.existsSync(), isTrue,
          reason: '$name exists in the recipe and not in this copy — the tier '
              'will compile against a version of host_media nobody wrote');
      expect(
        vendored.readAsStringSync(),
        File('$recipeDir/$name').readAsStringSync(),
        reason: '$vendorDir/$name has drifted from the recipe. Re-copy it '
            'from os/core/brain_kernel/recipes/host_media/lib/src/ — the '
            'recipe is the source, this is the copy.',
      );
    }
  });
}
