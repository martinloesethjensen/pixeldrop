// ignore_for_file: avoid_print

import 'package:backend/canvas_store.dart';
import 'package:backend/rate_limiter.dart';

void main() {
  // CanvasStore: setPixel / getPixel
  final store = CanvasStore()..setPixel(0, 0, 0xFF0000FF);
  assert(store.getPixel(0, 0) == 0xFF0000FF, 'setPixel/getPixel failed');
  print('✓ setPixel/getPixel');

  // CanvasStore: getChunkBytes length = 250 * 250 * 4 = 250000
  final bytes = store.getChunkBytes(0, 0);
  assert(
    bytes.length == 250 * 250 * 4,
    'chunk bytes length wrong: ${bytes.length}',
  );
  print('✓ getChunkBytes length = ${bytes.length}');

  // RateLimiter: first call allowed, second (immediate) blocked
  final limiter = RateLimiter();
  assert(limiter.isAllowed('user1'), 'first call should be allowed');
  limiter.record('user1');
  assert(!limiter.isAllowed('user1'), 'second call should be blocked');
  print('✓ RateLimiter: first allowed, second blocked');

  print('\nAll Phase 2 verification checks passed.');
}
