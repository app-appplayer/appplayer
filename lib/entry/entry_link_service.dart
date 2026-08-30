/// Listens for entry links and drives them through the standard's rules
/// (platform spec 19 §9.1, §9.2).
///
/// The plugin is the only part here that needs a device. Everything it feeds
/// — parsing, resolution, the decision — lives in `EntryController` and in the
/// core pipeline, so the behaviour is testable without one.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:http/http.dart' as http;

import 'entry_controller.dart';

/// The demo host this open-source build claims (§3.4).
///
/// Production media belong to the shipped product; a concept build that
/// intercepted them would take over scans it cannot fully serve, and a domain
/// is claimable by exactly one application.
const String kDemoEntryHost = 'demo.appplayer.app';

/// Where codes are dereferenced.
///
/// Not a fixed address any more: the resolver operates the entry host domain
/// (spec 19 §2), so the address follows the link. This is the path space it
/// is served on, and it is the same for every issuer — a host reads every
/// claimed domain with one controller.
const String kEntryResolverPath = HttpEntryResolver.defaultResolverPath;

/// Builds the controller Standard runs with.
EntryController buildEntryController({
  String resolverPath = kEntryResolverPath,
  Set<String>? claimedHosts,
  Logger? logger,
  EntryFetch? fetch,
}) {
  return EntryController(
    pipeline: EntryPipeline(
      resolver: HttpEntryResolver(
        path: resolverPath,
        fetch: fetch ?? _httpFetch,
        logger: logger,
      ),
      supportedTargets: EntryController.conceptTargets,
      // This build ships no sign-in, so it cannot serve an entry that demands
      // an identified viewer. Saying so is the honest answer; rendering it as
      // a guest would answer the demand by ignoring it.
      canIdentify: false,
      logger: logger,
    ),
    claimedHosts: claimedHosts ?? const <String>{kDemoEntryHost},
  );
}

Future<String> _httpFetch(
  Uri url, {
  Map<String, String> headers = const <String, String>{},
}) async {
  final response = await http.get(url, headers: headers);
  if (response.statusCode >= 400) {
    throw http.ClientException('HTTP ${response.statusCode}', url);
  }
  return response.body;
}

/// Subscribes to incoming links and hands each outcome to [onOutcome].
///
/// Both the cold-start link and later links go through the same call: an entry
/// that arrives while the app is already running is the same entry.
class EntryLinkService {
  EntryLinkService({
    required EntryController controller,
    required String Function() locale,
    AppLinks? links,
    Logger? logger,
  })  : _controller = controller,
        _locale = locale,
        _links = links ?? AppLinks(),
        _logger = logger ?? NoopLogger();

  final EntryController _controller;
  final String Function() _locale;
  final AppLinks _links;
  final Logger _logger;

  StreamSubscription<Uri>? _sub;

  Future<void> start(void Function(EntryOutcome) onOutcome) async {
    _sub = _links.uriLinkStream.listen(
      (uri) => _handle(uri, onOutcome),
      onError: (Object e) =>
          _logger.warn('entry.link.stream_error', {'error': e.toString()}),
    );
  }

  Future<void> _handle(Uri uri, void Function(EntryOutcome) onOutcome) async {
    try {
      final outcome = await _controller.handle(uri, locale: _locale());
      // A link that is not ours is not an error to report to the viewer — it
      // is logged and dropped here, and the host does whatever it normally
      // does with a URL.
      if (outcome is EntryNotForUs) {
        _logger.debug('entry.link.not_ours', {
          'reason': outcome.rejection.name,
          'host': uri.host,
        });
        return;
      }
      onOutcome(outcome);
    } catch (e, st) {
      // A scan must never crash the app it opened.
      _logger.logError('entry.link.failed', e, st, {'uri': uri.toString()});
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
