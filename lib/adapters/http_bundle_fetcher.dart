import 'dart:typed_data';

import 'package:appplayer_core/appplayer_core.dart';
import 'package:dio/dio.dart';

/// MOD-ADAPT-003 — BundleFetcher over HTTP(S) using Dio.
///
/// Retries on DioException / 5xx responses with exponential backoff.
class HttpBundleFetcher implements BundleFetcher {
  HttpBundleFetcher(
    this._dio, {
    this.maxRetries = 3,
    this.initialBackoff = const Duration(milliseconds: 500),
    this.receiveTimeout = const Duration(seconds: 30),
  });

  final Dio _dio;
  final int maxRetries;
  final Duration initialBackoff;
  final Duration receiveTimeout;

  @override
  Future<Uint8List> fetch(Uri url, {Map<String, String>? headers}) async {
    var attempt = 0;
    var delay = initialBackoff;
    while (true) {
      attempt++;
      try {
        final resp = await _dio.getUri<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: receiveTimeout,
            headers: headers,
          ),
        );
        final status = resp.statusCode ?? 0;
        if (status >= 200 && status < 300) {
          final data = resp.data;
          if (data == null) {
            throw const BundleFetchException('Empty body');
          }
          return Uint8List.fromList(data);
        }
        if (status >= 400 && status < 500) {
          throw BundleFetchException('HTTP $status');
        }
        if (attempt >= maxRetries) {
          throw BundleFetchException('HTTP $status');
        }
      } on DioException catch (e) {
        if (attempt >= maxRetries) {
          throw BundleFetchException(e.message ?? 'network');
        }
      }
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}

/// Surface-level exception raised when the host cannot deliver bundle bytes.
class BundleFetchException implements Exception {
  const BundleFetchException(this.message);
  final String message;

  @override
  String toString() => 'BundleFetchException: $message';
}
