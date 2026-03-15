import 'dart:typed_data';
import '../constants.dart';

class ChunkKey {
  const ChunkKey(this.cx, this.cy);

  factory ChunkKey.fromPixel(int x, int y) =>
      ChunkKey(x ~/ chunkSize, y ~/ chunkSize);

  final int cx;
  final int cy;

  int get index => cy * chunksX + cx;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkKey && cx == other.cx && cy == other.cy;

  @override
  int get hashCode => Object.hash(cx, cy);

  @override
  String toString() => 'ChunkKey($cx, $cy)';
}

class Chunk {
  Chunk({required this.key, required this.pixels})
      : assert(pixels.length == chunkSize * chunkSize);

  static Chunk white(ChunkKey key) => Chunk(
        key: key,
        pixels: Uint32List(chunkSize * chunkSize)..fillRange(0, chunkSize * chunkSize, 0xFFFFFFFF),
      );

  static Chunk fromBytes(ChunkKey key, Uint8List bytes) {
    final pixels = Uint32List(chunkSize * chunkSize);
    final byteData = ByteData.sublistView(bytes);
    for (var i = 0; i < pixels.length; i++) {
      pixels[i] = byteData.getUint32(i * 4);
    }
    return Chunk(key: key, pixels: pixels);
  }

  final ChunkKey key;
  final Uint32List pixels;

  int getPixel(int localX, int localY) => pixels[localY * chunkSize + localX];

  void setPixel(int localX, int localY, int argbColor) {
    pixels[localY * chunkSize + localX] = argbColor;
  }

  Uint8List toBytes() {
    final byteData = ByteData(pixels.length * 4);
    for (var i = 0; i < pixels.length; i++) {
      byteData.setUint32(i * 4, pixels[i]);
    }
    return byteData.buffer.asUint8List();
  }
}
