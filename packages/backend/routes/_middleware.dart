import 'dart:async';

import 'package:backend/canvas_store.dart';
import 'package:backend/connection_manager.dart';
import 'package:backend/rate_limiter.dart';
import 'package:dart_frog/dart_frog.dart';

final _canvasStore = CanvasStore();
final _connectionManager = ConnectionManager();
final _rateLimiter = RateLimiter();

Handler middleware(Handler handler) {
  Timer.periodic(
    const Duration(minutes: 1),
    (_) => _rateLimiter.cleanup(),
  );

  return handler
      .use(provider<CanvasStore>((_) => _canvasStore))
      .use(provider<ConnectionManager>((_) => _connectionManager))
      .use(provider<RateLimiter>((_) => _rateLimiter));
}
