import 'package:appplayer_core/appplayer_core.dart' show TransportType;

/// What a scanned QR code holds (FR-ENTRY-STD-010).
///
/// The scanner is a plain reader: it says what the code is and leaves what to
/// do with it to the person. Nothing here asks a resolver or checks a host.
sealed class QrContent {
  const QrContent();

  /// Reads [raw] as scanned.
  factory QrContent.classify(String raw) {
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    final isWeb = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    if (!isWeb) return QrText(text);
    if (uri.path.toLowerCase().endsWith('.mcpb')) return QrBundleLink(uri);
    return QrServerLink(uri);
  }
}

/// A web link to an installable bundle (`.mcpb`).
class QrBundleLink extends QrContent {
  const QrBundleLink(this.uri);
  final Uri uri;
}

/// Any other web link — a server to add, or a page to open.
class QrServerLink extends QrContent {
  const QrServerLink(this.uri);
  final Uri uri;

  /// The transport the address most likely speaks: `…/sse` is server-sent
  /// events, anything else Streamable HTTP. Only a first choice — the person
  /// sees and can change it in the form.
  TransportType get suggestedTransport =>
      uri.path.toLowerCase().endsWith('/sse')
          ? TransportType.sse
          : TransportType.streamableHttp;
}

/// A code that is not a web link: shown as the text it is.
class QrText extends QrContent {
  const QrText(this.text);
  final String text;
}
