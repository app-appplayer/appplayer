// FR-ENTRY-STD-010 — the result of a scan and what it offers.
import 'package:appplayer/entry/qr_content.dart';
import 'package:appplayer/ui/entry/entry_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpDialog(WidgetTester tester, QrContent content) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => ScanResultDialog(content: content),
          ),
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a link offers Add as server and Open link', (tester) async {
    await pumpDialog(tester, QrContent.classify('https://e.example/mcp'));
    expect(find.text('https://e.example/mcp'), findsOneWidget);
    expect(find.byKey(const Key('scan.add_server')), findsOneWidget);
    expect(find.byKey(const Key('scan.open_link')), findsOneWidget);
    expect(find.byKey(const Key('scan.add_bundle')), findsNothing);
    expect(find.byKey(const Key('scan.again')), findsOneWidget);
  });

  testWidgets('a bundle link offers Add bundle', (tester) async {
    await pumpDialog(tester, QrContent.classify('https://e.example/a.mcpb'));
    expect(find.byKey(const Key('scan.add_bundle')), findsOneWidget);
    expect(find.byKey(const Key('scan.add_server')), findsNothing);
    expect(find.byKey(const Key('scan.open_link')), findsNothing);
  });

  testWidgets('text that is not a link shows the text and only Scan again',
      (tester) async {
    await pumpDialog(tester, QrContent.classify('hello world'));
    expect(find.text('Not a link'), findsOneWidget);
    expect(find.text('hello world'), findsOneWidget);
    expect(find.byKey(const Key('scan.again')), findsOneWidget);
    expect(find.byKey(const Key('scan.add_server')), findsNothing);
    expect(find.byKey(const Key('scan.open_link')), findsNothing);
    expect(find.byKey(const Key('scan.add_bundle')), findsNothing);
  });

  testWidgets('Scan again closes the dialog', (tester) async {
    await pumpDialog(tester, QrContent.classify('hello'));
    await tester.tap(find.byKey(const Key('scan.again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan.result')), findsNothing);
  });
}
