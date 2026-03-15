import 'dart:typed_data';
import 'package:shared/shared.dart';

class CanvasStore {
  CanvasStore()
      : _pixels = Uint32List(canvasWidth * canvasHeight)
          ..fillRange(0, canvasWidth * canvasHeight, 0xFFFFFFFF);

  final Uint32List _pixels;

  int _index(int x, int y) => y * canvasWidth + x;

  void setPixel(int x, int y, int color) {
    if (x < 0 || x >= canvasWidth || y < 0 || y >= canvasHeight) return;
    _pixels[_index(x, y)] = color;
  }

  int getPixel(int x, int y) => _pixels[_index(x, y)];

  Uint8List getChunkBytes(int cx, int cy) {
    final bytes = ByteData(chunkSize * chunkSize * 4);
    final originX = cx * chunkSize;
    final originY = cy * chunkSize;
    var byteOffset = 0;
    for (var row = 0; row < chunkSize; row++) {
      for (var col = 0; col < chunkSize; col++) {
        final pixel = _pixels[_index(originX + col, originY + row)];
        bytes.setUint32(byteOffset, pixel);
        byteOffset += 4;
      }
    }
    return bytes.buffer.asUint8List();
  }
}
