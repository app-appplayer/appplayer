import 'dart:typed_data';

/// No file system here. The caller treats null as "no waveform", which is what
/// the widget then reports.
Future<Uint8List?> localFileBytes(String uri) async => null;
