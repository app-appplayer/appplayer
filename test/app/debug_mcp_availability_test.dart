// The Debug MCP endpoint is not available in a mobile release build.
import 'package:appplayer/app/debug_mcp_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool on({bool web = false, bool mobile = false, bool release = false}) =>
      debugMcpAvailableOn(isWeb: web, isMobile: mobile, isRelease: release);

  test('a mobile release build has no Debug MCP', () {
    expect(on(mobile: true, release: true), isFalse);
  });

  test('a mobile debug or profile build keeps it for development', () {
    expect(on(mobile: true), isTrue);
  });

  test('desktop keeps it in every build mode', () {
    expect(on(), isTrue);
    expect(on(release: true), isTrue);
  });

  test('the web has none', () {
    expect(on(web: true), isFalse);
    expect(on(web: true, release: true), isFalse);
  });
}
