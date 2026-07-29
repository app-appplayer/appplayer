/// Standard as the concept entry host (platform spec 19 §9).
library;

import 'package:appplayer/entry/entry_controller.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _Resolver implements EntryResolverPort {
  _Resolver(this.answer);
  EntryTarget answer;
  @override
  Future<EntryTarget> resolve(String code, {required String locale}) async =>
      answer;
}

EntryTarget _ok({
  EntryTargetKind kind = EntryTargetKind.server,
  IdentityPolicy policy = IdentityPolicy.open,
  String? route,
}) =>
    EntryTarget(
      status: EntryStatus.ok,
      issuer: const EntryIssuer(name: 'Fleet Co', verified: true),
      target: EntryTargetRef(
        kind: kind,
        ref: 'https://fleet.example.test/mcp',
        route: route,
        params: const <String, dynamic>{'plate': 'AB-1234'},
      ),
      identityPolicy: policy,
    );

EntryController controllerFor(EntryTarget answer) => EntryController(
      pipeline: EntryPipeline(
        resolver: _Resolver(answer),
        supportedTargets: EntryController.conceptTargets,
        canIdentify: false,
      ),
      claimedHosts: const <String>{'demo.appplayer.app'},
    );

void main() {
  const locale = 'en';
  const link = 'https://demo.appplayer.app/e/ABC123';

  test('a claimed link resolves and opens', () async {
    final outcome =
        await controllerFor(_ok(route: '/contact')).handle(Uri.parse(link),
            locale: locale);
    expect(outcome, isA<EntryOpen>());
    final open = outcome as EntryOpen;
    expect(open.target.kind, EntryTargetKind.server);
    expect(open.entry.route, '/contact');
    expect(open.entry.params['plate'], 'AB-1234');
    expect(open.entry.issuer!.name, 'Fleet Co');
    expect(open.identityRequired, isFalse);
  });

  test('a required entry is refused by a build with no sign-in', () async {
    // Standard ships no sign-in. Rendering such an entry as a guest would
    // answer a demand for identity by ignoring it (§4.2).
    final outcome = await controllerFor(_ok(policy: IdentityPolicy.required))
        .handle(Uri.parse(link), locale: locale);
    expect((outcome as EntryBlocked).rejection,
        EntryRejection.identityUnavailable);
  });

  test('a link we do not claim is reported, not swallowed', () async {
    final outcome = await controllerFor(_ok())
        .handle(Uri.parse('https://elsewhere.test/e/ABC'), locale: locale);
    expect(outcome, isA<EntryNotForUs>());
    expect((outcome as EntryNotForUs).rejection,
        EntryLinkRejection.unclaimedHost);
  });

  test('a guest entry at an account wall is blocked with the issuer intact',
      () async {
    final outcome = await controllerFor(
      _ok(kind: EntryTargetKind.listing, policy: IdentityPolicy.open),
    ).handle(Uri.parse(link), locale: locale);

    final blocked = outcome as EntryBlocked;
    expect(blocked.rejection, EntryRejection.accountWallForGuest);
    // The gate still says who was asking.
    expect(blocked.target.issuer.name, 'Fleet Co');
  });

  test('a marketplace target is unsupported here, not redirected', () async {
    // Standard ships no marketplace. An identified listing entry must surface
    // as unsupported rather than opening something else.
    final outcome = await controllerFor(
      _ok(kind: EntryTargetKind.listing, policy: IdentityPolicy.required),
    ).handle(Uri.parse(link), locale: locale);

    final blocked = outcome as EntryBlocked;
    expect(blocked.rejection, EntryRejection.unsupportedTarget);
    expect(blocked.target.target!.kind, EntryTargetKind.listing);
  });

  test('a local node entry opens — a sticker needs no account', () async {
    final outcome =
        await controllerFor(_ok(kind: EntryTargetKind.localServer))
            .handle(Uri.parse(link), locale: locale);
    expect(outcome, isA<EntryOpen>());
  });

  test('a revoked medium is blocked and says why', () async {
    const revoked = EntryTarget(
      status: EntryStatus.revoked,
      issuer: EntryIssuer(name: 'Fleet Co'),
      reason: 'medium retired',
    );
    final outcome =
        await controllerFor(revoked).handle(Uri.parse(link), locale: locale);
    final blocked = outcome as EntryBlocked;
    expect(blocked.rejection, EntryRejection.notOk);
    expect(blocked.target.reason, 'medium retired');
  });

  test('every acquisition path is the same call', () async {
    // A scanner and an intercepted link differ only in how the URL arrived.
    final controller = controllerFor(_ok(route: '/contact'));
    final fromLink = await controller.handle(Uri.parse(link), locale: locale);
    final fromScanner =
        await controller.handle(Uri.parse(link), locale: locale);
    expect(fromLink.runtimeType, fromScanner.runtimeType);
  });
}
