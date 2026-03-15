import 'dart:convert';

import 'package:shared/shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ConnectionManager {
  final Map<String, WebSocketChannel> _connections = {};

  void add(String id, WebSocketChannel ch) {
    _connections[id] = ch;
  }

  void remove(String id) {
    _connections.remove(id);
  }

  void broadcast(WsMessage msg) {
    final encoded = jsonEncode(msg.toJson());
    for (final ch in _connections.values) {
      ch.sink.add(encoded);
    }
  }

  void sendTo(String id, WsMessage msg) {
    _connections[id]?.sink.add(jsonEncode(msg.toJson()));
  }

  int get userCount => _connections.length;
}
