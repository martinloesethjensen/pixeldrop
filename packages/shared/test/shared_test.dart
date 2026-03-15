import 'dart:convert';
import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  group('WsMessage round-trip', () {
    test('PixelUpdate encodes and decodes', () {
      const msg = PixelUpdate(
        pixel: Pixel(x: 10, y: 20, color: 0xFFFF0000),
        userId: 'user-1',
      );
      final decoded = WsMessage.fromJson(
        jsonDecode(jsonEncode(msg.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, equals(msg));
    });

    test('RateLimitError encodes and decodes', () {
      const msg = RateLimitError(retryAfterMs: 3000);
      final decoded = WsMessage.fromJson(
        jsonDecode(jsonEncode(msg.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, equals(msg));
    });

    test('UserCount encodes and decodes', () {
      const msg = UserCount(count: 42);
      final decoded = WsMessage.fromJson(
        jsonDecode(jsonEncode(msg.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, equals(msg));
    });

    test('BatchUpdate encodes and decodes', () {
      const msg = BatchUpdate(updates: [
        PixelUpdate(pixel: Pixel(x: 1, y: 2, color: 0xFF000000), userId: 'a'),
        PixelUpdate(pixel: Pixel(x: 3, y: 4, color: 0xFFFFFFFF), userId: 'b'),
      ]);
      final decoded = WsMessage.fromJson(
        jsonDecode(jsonEncode(msg.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, equals(msg));
    });
  });

  group('ChunkKey', () {
    test('fromPixel divides by chunkSize', () {
      final key = ChunkKey.fromPixel(300, 750);
      expect(key.cx, 1);
      expect(key.cy, 3);
    });

    test('index is cy * chunksX + cx', () {
      expect(ChunkKey(1, 3).index, 13);
      expect(ChunkKey(0, 0).index, 0);
      expect(ChunkKey(3, 3).index, 15);
    });

    test('equality and hashCode', () {
      expect(ChunkKey(2, 1), equals(ChunkKey(2, 1)));
      expect(ChunkKey(2, 1).hashCode, equals(ChunkKey(2, 1).hashCode));
    });
  });

  group('Chunk', () {
    test('white initialises all pixels to 0xFFFFFFFF', () {
      final chunk = Chunk.white(ChunkKey(0, 0));
      expect(chunk.pixels.every((p) => p == 0xFFFFFFFF), isTrue);
    });

    test('setPixel / getPixel round-trip', () {
      final chunk = Chunk.white(ChunkKey(0, 0));
      chunk.setPixel(5, 10, 0xFFABCDEF);
      expect(chunk.getPixel(5, 10), 0xFFABCDEF);
    });

    test('toBytes / fromBytes round-trip', () {
      final chunk = Chunk.white(ChunkKey(1, 2));
      chunk.setPixel(0, 0, 0xFF112233);
      final restored = Chunk.fromBytes(ChunkKey(1, 2), chunk.toBytes());
      expect(restored.getPixel(0, 0), 0xFF112233);
      expect(restored.key, equals(chunk.key));
    });
  });
}
