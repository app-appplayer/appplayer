import 'dart:typed_data';

import 'package:appplayer/adapters/http_bundle_fetcher.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://x'));
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late HttpBundleFetcher fetcher;

  setUp(() {
    dio = _MockDio();
    fetcher = HttpBundleFetcher(
      dio,
      maxRetries: 3,
      initialBackoff: const Duration(milliseconds: 1),
    );
  });

  Response<List<int>> resp(int status, [List<int>? body]) {
    return Response<List<int>>(
      requestOptions: RequestOptions(path: ''),
      statusCode: status,
      data: body,
    );
  }

  test('TC-HBF-001 200 OK returns bytes', () async {
    when(() => dio.getUri<List<int>>(any(), options: any(named: 'options')))
        .thenAnswer((_) async => resp(200, [0x01, 0x02]));

    final bytes = await fetcher.fetch(Uri.parse('https://x/y.mcpb'));
    expect(bytes, equals(Uint8List.fromList([0x01, 0x02])));
  });

  test('TC-HBF-001a passes headers', () async {
    Options? seen;
    when(() => dio.getUri<List<int>>(any(), options: any(named: 'options')))
        .thenAnswer((inv) async {
      seen = inv.namedArguments[#options] as Options?;
      return resp(200, [0x01]);
    });

    await fetcher.fetch(Uri.parse('https://x'), headers: const {'A': 'B'});
    expect(seen?.headers?['A'], 'B');
  });

  test('TC-HBF-002 404 no retry', () async {
    var calls = 0;
    when(() => dio.getUri<List<int>>(any(), options: any(named: 'options')))
        .thenAnswer((_) async {
      calls++;
      return resp(404);
    });

    await expectLater(
      fetcher.fetch(Uri.parse('https://x')),
      throwsA(isA<BundleFetchException>()),
    );
    expect(calls, 1);
  });

  test('TC-HBF-003 retries 500 then succeeds', () async {
    var calls = 0;
    when(() => dio.getUri<List<int>>(any(), options: any(named: 'options')))
        .thenAnswer((_) async {
      calls++;
      if (calls < 3) return resp(500);
      return resp(200, [0x09]);
    });

    final bytes = await fetcher.fetch(Uri.parse('https://x'));
    expect(bytes, equals(Uint8List.fromList([0x09])));
    expect(calls, 3);
  });

  test('TC-HBF-004 exceeds maxRetries on 500', () async {
    when(() => dio.getUri<List<int>>(any(), options: any(named: 'options')))
        .thenAnswer((_) async => resp(500));

    await expectLater(
      fetcher.fetch(Uri.parse('https://x')),
      throwsA(isA<BundleFetchException>()),
    );
  });

  test('TC-HBF-005 DioException retries until success', () async {
    var calls = 0;
    when(() => dio.getUri<List<int>>(any(), options: any(named: 'options')))
        .thenAnswer((_) async {
      calls++;
      if (calls < 3) {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.receiveTimeout,
        );
      }
      return resp(200, [0x07]);
    });

    final bytes = await fetcher.fetch(Uri.parse('https://x'));
    expect(bytes, equals(Uint8List.fromList([0x07])));
    expect(calls, 3);
  });
}
