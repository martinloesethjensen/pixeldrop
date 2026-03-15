class Pixel {
  const Pixel({required this.x, required this.y, required this.color});

  factory Pixel.fromJson(Map<String, dynamic> json) => Pixel(
        x: json['x'] as int,
        y: json['y'] as int,
        color: json['color'] as int,
      );

  final int x;
  final int y;
  final int color; // ARGB int

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'color': color};

  Pixel copyWith({int? x, int? y, int? color}) => Pixel(
        x: x ?? this.x,
        y: y ?? this.y,
        color: color ?? this.color,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pixel && x == other.x && y == other.y && color == other.color;

  @override
  int get hashCode => Object.hash(x, y, color);
}
