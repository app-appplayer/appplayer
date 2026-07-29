/// Reading an entry code out of a Play referrer (platform spec 19 §3.5).
library;

import 'package:appplayer/entry/deferred_entry_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the entry code is read out of a referrer', () {
    expect(codeFromReferrer('entry_code=ABC123'), 'ABC123');
  });

  test('other referrer parameters are left alone', () {
    // The referrer belongs to whoever built the store link; guessing at the
    // rest of it is not ours to do.
    expect(
      codeFromReferrer('utm_source=qr&entry_code=ABC123&utm_medium=print'),
      'ABC123',
    );
  });

  test('a partitioned code survives percent-encoding', () {
    // Without decoding, `fleet/ABC` arrives as `fleet%2FABC` and resolves
    // against nothing.
    expect(codeFromReferrer('entry_code=fleet%2FABC123'), 'fleet/ABC123');
  });

  test('a referrer with no entry code yields nothing', () {
    expect(codeFromReferrer('utm_source=organic'), isNull);
    expect(codeFromReferrer(''), isNull);
    expect(codeFromReferrer('entry_code='), isNull);
  });

  test('a key that merely contains the name is not the key', () {
    expect(codeFromReferrer('not_entry_code=ABC'), isNull);
  });

  test('malformed pairs are skipped rather than throwing', () {
    expect(codeFromReferrer('=novalue&entry_code=OK'), 'OK');
  });
}
