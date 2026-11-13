import 'dart:convert';
import 'dart:typed_data';

import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/core/network/bridge_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
  final List<String> paths = [];
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(o.path);
    authHeaders.add(o.headers['Authorization'] as String?);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      throw DioException.connectionError(requestOptions: o, reason: 'simulated offline');

  @override
  void close({bool force = false}) {}
}

BridgeClient _client(HttpClientAdapter adapter, {String? controlToken}) {
  return BridgeClient(
    baseUrl: 'http://bridge.test/api/v1',
    dio: Dio(BaseOptions(baseUrl: 'http://bridge.test/api/v1'))
      ..httpClientAdapter = adapter,
    controlToken: controlToken,
  );
}

void main() {
  test('a control call is refused before any request when no credential exists', () async {
    final adapter = _RecordingAdapter(200, {'paused': false});
    await expectLater(
      _client(adapter).post('/control/toggle', body: {'action': 'pause'}, requiresControlToken: true),
      throwsA(isA<AuthorizationException>()),
    );
    expect(adapter.paths, isEmpty);
  });

  test('a control call carries the bridge credential; reads carry none', () async {
    final adapter = _RecordingAdapter(200, {'paused': false, 'action': 'pause'});
    final client = _client(adapter, controlToken: 'control-jwt');
    await client.post('/control/toggle', body: {'action': 'pause'}, requiresControlToken: true);
    await client.checkHealth();
    expect(adapter.authHeaders, ['Bearer control-jwt', null]);
  });

  test('a licence activation needs no control credential — the key is the credential', () async {
    final adapter = _RecordingAdapter(200, {'service_type': 'SIGNALS', 'status': 'ACTIVE'});
    final client = _client(adapter);
    await client.post('/license/activate', body: {'key': 'PH-SIGNALS-ABC', 'service_type': 'SIGNALS'});
    expect(adapter.authHeaders, [null]);
    expect(adapter.paths, ['/license/activate']);
  });

  test('reads return the bare bridge object, not an envelope', () async {
    final client = _client(_RecordingAdapter(200, {'mt5_ipc': 'CONNECTED', 'paused': false}));
    expect(await client.checkHealth(), {'mt5_ipc': 'CONNECTED', 'paused': false});
  });

  test('a licence rejection surfaces its reason and never echoes the key', () async {
    final client = _client(_RecordingAdapter(403, {'detail': 'hardware binding mismatch'}));
    await expectLater(
      client.post('/license/activate', body: {'key': 'PH-SIGNALS-SECRET', 'service_type': 'SIGNALS'}),
      throwsA(
        isA<AuthorizationException>().having(
          (e) => e.message,
          'message',
          'hardware binding mismatch',
        ),
      ),
    );
  });

  test('an expired key is reported as expired', () async {
    final client = _client(_RecordingAdapter(403, {'detail': 'key expired'}), controlToken: 't');
    await expectLater(
      client.post('/license/activate', body: {'key': 'k', 'service_type': 'SIGNALS'}),
      throwsA(isA<AuthorizationException>().having((e) => e.message, 'message', 'key expired')),
    );
  });

  test('an unreachable bridge is a network state, not an empty dashboard', () async {
    await expectLater(_client(_OfflineAdapter()).checkHealth(), throwsA(isA<NetworkException>()));
  });

  test('a 5xx bridge is a server state', () async {
    await expectLater(
      _client(_RecordingAdapter(500, {'detail': 'internal error'})).checkHealth(),
      throwsA(isA<ServerException>()),
    );
  });
}
