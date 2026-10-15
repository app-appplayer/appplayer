/// Scanning a code (platform spec 19 §9.2).
///
/// A scanner is one acquisition source among three. It produces the same URL
/// an intercepted link would, and hands it to the same call — nothing about
/// what follows knows which door the code came through.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../entry/qr_content.dart';

/// Whether this build offers scanning at all. A switch rather than a deletion
/// so a build that does not want a camera button can leave it out.
const bool kEntryScanOffered = true;

/// Whether this build can open a camera scanner — the platforms the scanner
/// plugin implements. Elsewhere scanning is not offered at all, rather than
/// offered and opening a screen with no camera behind it.
bool entryScanSupported({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
  bool offered = kEntryScanOffered,
}) {
  if (!offered) return false;
  if (isWeb) return true;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// A plain QR reader (FR-ENTRY-STD-010): it shows what the code holds and
/// offers what can be done with it. It asks no resolver and checks no host,
/// and nothing is connected or opened until the person chooses.
class EntryScanScreen extends StatefulWidget {
  const EntryScanScreen({super.key});

  @override
  State<EntryScanScreen> createState() => _EntryScanScreenState();
}

class _EntryScanScreenState extends State<EntryScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  /// A camera fires the same code many times a second; one result at a time.
  bool _handling = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    _handling = true;
    try {
      await _showResult(QrContent.classify(raw));
    } finally {
      _handling = false;
    }
  }

  Future<void> _showResult(QrContent content) async {
    final choice = await showDialog<_ScanChoice>(
      context: context,
      builder: (_) => ScanResultDialog(content: content),
    );
    if (!mounted || choice == null || choice == _ScanChoice.scanAgain) return;

    switch ((choice, content)) {
      case (_ScanChoice.install, QrBundleLink(:final uri)):
        _openForm('bundle', uri);
      case (_ScanChoice.addServer, QrServerLink(:final uri)):
        _openForm('server', uri);
      case (_ScanChoice.openLink, QrServerLink(:final uri)):
        await _openLink(uri);
      default:
        break;
    }
  }

  void _openForm(String type, Uri uri) {
    final url = Uri.encodeQueryComponent(uri.toString());
    context.pushReplacement('/apps/new?type=$type&url=$url');
  }

  Future<void> _openLink(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing on this device can open that link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a code')),
      body: MobileScanner(controller: _scanner, onDetect: _onDetect),
    );
  }
}

/// What the person chose on the result dialog.
enum _ScanChoice { install, addServer, openLink, scanAgain }

/// Shows what was read and the actions that fit it (FR-ENTRY-STD-010).
class ScanResultDialog extends StatelessWidget {
  const ScanResultDialog({super.key, required this.content});

  final QrContent content;

  @override
  Widget build(BuildContext context) {
    final (String shown, String title, List<Widget> actions) = switch (content) {
      QrBundleLink(:final uri) => (
          uri.toString(),
          'App bundle',
          <Widget>[
            _action(context, 'scan.install', 'Install', _ScanChoice.install),
          ],
        ),
      QrServerLink(:final uri) => (
          uri.toString(),
          'Link',
          <Widget>[
            _action(context, 'scan.add_server', 'Add as server',
                _ScanChoice.addServer),
            _action(context, 'scan.open_link', 'Open link', _ScanChoice.openLink),
          ],
        ),
      QrText(:final text) => (text, 'Not a link', const <Widget>[]),
    };
    return AlertDialog(
      key: const Key('scan.result'),
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText(shown)),
      actions: <Widget>[
        TextButton(
          key: const Key('scan.again'),
          onPressed: () => Navigator.of(context).pop(_ScanChoice.scanAgain),
          child: const Text('Scan again'),
        ),
        ...actions,
      ],
    );
  }

  Widget _action(
          BuildContext context, String key, String label, _ScanChoice choice) =>
      TextButton(
        key: Key(key),
        onPressed: () => Navigator.of(context).pop(choice),
        child: Text(label),
      );
}
