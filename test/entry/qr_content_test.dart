// FR-ENTRY-STD-010 — what a scanned QR code is.
import 'package:appplayer/entry/qr_content.dart';
import 'package:appplayer_core/appplayer_core.dart' show TransportType;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a web link', () {
    test('is a server link, whatever its host', () {
      for (final raw in <String>[
        'https://example.com/mcp',
        'http://192.168.0.5:3001/sse',
        'https://api.safepage.app/e/ABC123',
        'HTTPS://Mixed.Case.example/x',
      ]) {
        expect(QrContent.classify(raw), isA<QrServerLink>(), reason: raw);
      }
    });

    test('ending in .mcpb is a bundle link, query or not', () {
      expect(QrContent.classify('https://example.com/apps/demo.mcpb'),
          isA<QrBundleLink>());
      expect(QrContent.classify('https://example.com/apps/Demo.MCPB'),
          isA<QrBundleLink>());
      // The extension is the path's end; a query that mentions it is a link.
      expect(QrContent.classify('https://example.com/get?file=demo.mcpb'),
          isA<QrServerLink>());
      expect(QrContent.classify('https://example.com/demo.mcpb?token=1'),
          isA<QrBundleLink>());
    });

    test('keeps the address as read, with surrounding space dropped', () {
      final c = QrContent.classify('  https://example.com/mcp?a=1#x \n');
      expect((c as QrServerLink).uri.toString(), 'https://example.com/mcp?a=1#x');
    });

    test('suggests SSE only for an address that ends in /sse', () {
      expect(
          (QrContent.classify('https://e.example/sse') as QrServerLink)
              .suggestedTransport,
          TransportType.sse);
      expect(
          (QrContent.classify('https://e.example/mcp') as QrServerLink)
              .suggestedTransport,
          TransportType.streamableHttp);
      expect(
          (QrContent.classify('https://e.example/assets') as QrServerLink)
              .suggestedTransport,
          TransportType.streamableHttp);
    });
  });

  group('anything else is text', () {
    test('plain text, other schemes, a bare code, an empty read', () {
      for (final raw in <String>[
        'hello world',
        'tel:+8212345678',
        'mailto:a@b.example',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'ftp://example.com/x.mcpb',
        'A7K29',
        'https://',
        '',
      ]) {
        expect(QrContent.classify(raw), isA<QrText>(), reason: raw);
      }
    });

    test('carries the text back for display', () {
      expect((QrContent.classify(' hello ') as QrText).text, 'hello');
    });
  });
}
