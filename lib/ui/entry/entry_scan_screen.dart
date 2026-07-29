/// Scanning a code (platform spec 19 §9.2).
///
/// A scanner is one acquisition source among three. It produces the same URL
/// an intercepted link would, and hands it to the same call — nothing about
/// what follows knows which door the code came through.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../entry/entry_controller.dart';
import '../../entry/entry_outcome_router.dart';

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

  /// A camera fires the same code many times a second. Without this the first
  /// resolution would still be in flight while the next twenty started.
  bool _handling = false;
  String? _message;

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

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      setState(() => _message = 'That code is not a link.');
      return;
    }

    _handling = true;
    try {
      final controller = context.read<EntryController>();
      final outcome = await controller.handle(
        uri,
        locale: Localizations.localeOf(context).toLanguageTag(),
      );
      if (!mounted) return;

      final router = GoRouter.of(context);
      // Leave the camera before showing the result: coming back from the
      // opened app should land where the scan started, not on a live preview.
      Navigator.of(context).pop();
      final shown = routeEntryOutcome(router, outcome);
      if (!shown) {
        // Scanning something we do not claim is worth saying out loud — the
        // person aimed at it deliberately.
        _message = 'That code is not for this app.';
      }
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a code')),
      body: Stack(
        children: <Widget>[
          MobileScanner(controller: _scanner, onDetect: _onDetect),
          if (message != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(message),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
