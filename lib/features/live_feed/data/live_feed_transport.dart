import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// The socket the live feed runs on, behind an interface so the service's
/// reconnect/heartbeat/duplicate logic is testable without a real socket.
abstract interface class LiveFeedTransport {
  /// Resolves once the socket is open, or throws if the handshake fails.
  Future<void> connect(Uri uri);

  /// Every frame the server sends, until the socket closes.
  Stream<dynamic> get messages;

  /// A keepalive frame; the bridge never reads payloads, it only keeps the
  /// connection warm.
  Future<void> send(String frame);

  Future<void> close();
}

class WebSocketLiveFeedTransport implements LiveFeedTransport {
  WebSocketLiveFeedTransport({WebSocketChannel Function(Uri uri)? connect})
      : _connect = connect ?? WebSocketChannel.connect;

  final WebSocketChannel Function(Uri uri) _connect;
  WebSocketChannel? _channel;

  @override
  Future<void> connect(Uri uri) async {
    final channel = _connect(uri);
    _channel = channel;
    // A rejected licence closes with 1008 instead of completing the handshake,
    // so the error surfaces from this await rather than mid-stream.
    await channel.ready;
  }

  @override
  Stream<dynamic> get messages => _channel!.stream;

  @override
  Future<void> send(String frame) async => _channel?.sink.add(frame);

  @override
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }
}

/// A transport that always fails, for mock mode and for proving the
/// "bridge unavailable" UI without a network.
class UnavailableLiveFeedTransport implements LiveFeedTransport {
  @override
  Future<void> connect(Uri uri) async => throw const SocketExceptionStub();

  @override
  Stream<dynamic> get messages => const Stream.empty();

  @override
  Future<void> send(String frame) async {}

  @override
  Future<void> close() async {}
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'Live trading bridge unreachable';
}
