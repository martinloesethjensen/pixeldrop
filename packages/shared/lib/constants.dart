const int canvasWidth = 1000;
const int canvasHeight = 1000;
const int chunkSize = 250;
const int chunksX = 4; // 1000 ÷ 250
const int chunksY = 4; // 1000 ÷ 250
const int totalChunks = 16;

const Duration pixelCooldown = Duration(seconds: 5);

// r/place 2022 palette — 16 ARGB ints
const List<int> presetColours = <int>[
  0xFF6D001A, // dark red
  0xFFBE0039, // red
  0xFFFF4500, // orange
  0xFFFFA800, // yellow
  0xFF00A368, // dark green
  0xFF00CC78, // green
  0xFF009EAA, // dark teal
  0xFF00CCC0, // teal
  0xFF2450A4, // dark blue
  0xFF3690EA, // blue
  0xFF493AC1, // dark purple
  0xFF6A5CFF, // purple
  0xFFFFFFFF, // white
  0xFFD4D7D9, // light grey
  0xFF898D90, // dark grey
  0xFF000000, // black
];
