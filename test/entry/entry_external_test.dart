/// An external entry is a destination to confirm, not a session to open
/// (platform spec 19 §9.7).
library;

import 'package:appplayer/entry/entry_controller.dart';
import 'package:appplayer/ui/entry/entry_open_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EntryOpen _external(String ref) => EntryOpen(
      target: EntryTargetRef(kind: EntryTargetKind.external, ref: ref),
      entry: EntryContext(
        issuer: const EntryIssuer(name: 'Parking Co', verified: true),
      ),
      identityRequired: false,
    );

void main() {
  testWidgets('the issuer and the destination come first, nothing leaves',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EntryOpenScreen(open: _external('tel:+821000000000')),
    ));
    expect(find.text('Parking Co'), findsOneWidget);
    expect(find.text('tel:+821000000000'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.textContaining('cannot open'), findsNothing);
  });

  testWidgets('an address this app does not hand over stops', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EntryOpenScreen(open: _external('intent://x#Intent;end')),
    ));
    expect(find.text('Parking Co'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });
}
