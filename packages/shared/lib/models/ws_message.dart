import 'pixel.dart';

sealed class WsMessage {
  const WsMessage();

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'pixel_update' => PixelUpdate.fromJson(json),
      'rate_limit_error' => RateLimitError.fromJson(json),
      'user_count' => UserCount.fromJson(json),
      'batch_update' => BatchUpdate.fromJson(json),
      _ => throw ArgumentError('Unknown WsMessage type: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

class PixelUpdate extends WsMessage {
  const PixelUpdate({required this.pixel, required this.userId});

  factory PixelUpdate.fromJson(Map<String, dynamic> json) => PixelUpdate(
        pixel: Pixel.fromJson(json['pixel'] as Map<String, dynamic>),
        userId: json['userId'] as String,
      );

  final Pixel pixel;
  final String userId;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pixel_update',
        'pixel': pixel.toJson(),
        'userId': userId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PixelUpdate && pixel == other.pixel && userId == other.userId;

  @override
  int get hashCode => Object.hash(pixel, userId);
}

class RateLimitError extends WsMessage {
  const RateLimitError({required this.retryAfterMs});

  factory RateLimitError.fromJson(Map<String, dynamic> json) =>
      RateLimitError(retryAfterMs: json['retryAfterMs'] as int);

  final int retryAfterMs;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'rate_limit_error',
        'retryAfterMs': retryAfterMs,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RateLimitError && retryAfterMs == other.retryAfterMs;

  @override
  int get hashCode => retryAfterMs.hashCode;
}

class UserCount extends WsMessage {
  const UserCount({required this.count});

  factory UserCount.fromJson(Map<String, dynamic> json) =>
      UserCount(count: json['count'] as int);

  final int count;

  @override
  Map<String, dynamic> toJson() => {'type': 'user_count', 'count': count};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserCount && count == other.count;

  @override
  int get hashCode => count.hashCode;
}

class BatchUpdate extends WsMessage {
  const BatchUpdate({required this.updates});

  factory BatchUpdate.fromJson(Map<String, dynamic> json) => BatchUpdate(
        updates: (json['updates'] as List<dynamic>)
            .map((e) => PixelUpdate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final List<PixelUpdate> updates;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'batch_update',
        'updates': updates.map((u) => u.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchUpdate &&
          updates.length == other.updates.length &&
          List.generate(updates.length, (i) => updates[i] == other.updates[i])
              .every((e) => e);

  @override
  int get hashCode => Object.hashAll(updates);
}
