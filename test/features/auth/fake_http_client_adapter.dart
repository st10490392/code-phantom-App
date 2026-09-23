import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// A single canned response (or simulated transport failure) for
/// [FakeHttpClientAdapter] to return for one matching request.
class FakeResponse {
  const FakeResponse({required this.statusCode, this.body = const {}})
      : isNetworkFailure = false;

  /// A response that never arrives — simulates offline/DNS/connection
  /// failure. [FakeHttpClientAdapter] throws instead of returning a
  /// [ResponseBody] when this is used, which Dio wraps into a
  /// `DioException` with a null `response` — exactly what a real network
  /// failure looks like to `mapDioException`.
  const FakeResponse.networkFailure()
      : statusCode = -1,
        body = const {},
        isNetworkFailure = true;

  final int statusCode;
  final Map<String, dynamic> body;
  final bool isNetworkFailure;
}

/// Fake Dio transport for tests — no real network call is ever made.
/// [handler] inspects the outgoing request (method/path/body) and returns
/// the [FakeResponse] to simulate.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.handler);

  final FakeResponse Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = handler(options);
    if (response.isNetworkFailure) {
      throw const SocketExceptionStub();
    }
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Stand-in for `dart:io`'s `SocketException` so this test helper doesn't
/// need a `dart:io` import — Dio only cares that `fetch` threw, not what.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'Simulated network failure';
}
