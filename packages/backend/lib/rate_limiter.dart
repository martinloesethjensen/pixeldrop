import 'package:shared/shared.dart';

class RateLimiter {
  final Map<String, DateTime> _lastPlacement = {};

  bool isAllowed(String userId) {
    final last = _lastPlacement[userId];
    if (last == null) return true;
    return DateTime.now().difference(last) > pixelCooldown;
  }

  void record(String userId) {
    _lastPlacement[userId] = DateTime.now();
  }

  int retryAfterMs(String userId) {
    final last = _lastPlacement[userId];
    if (last == null) return 0;
    final elapsed = DateTime.now().difference(last);
    final remaining = pixelCooldown - elapsed;
    return remaining.isNegative ? 0 : remaining.inMilliseconds;
  }

  void cleanup() {
    final cutoff = DateTime.now().subtract(pixelCooldown * 2);
    _lastPlacement.removeWhere((_, last) => last.isBefore(cutoff));
  }
}
