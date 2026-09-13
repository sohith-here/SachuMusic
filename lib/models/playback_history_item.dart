import 'song.dart';

class PlaybackHistoryItem {
  final String id;
  final Song song;
  final DateTime playedAt;

  const PlaybackHistoryItem({
    required this.id,
    required this.song,
    required this.playedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'playedAt': playedAt.toIso8601String(),
      'song': song.toMap(),
    };
  }

  factory PlaybackHistoryItem.fromMap(Map<String, dynamic> map) {
    return PlaybackHistoryItem(
      id: map['id'] as String? ?? '',
      playedAt:
          DateTime.tryParse(map['playedAt'] as String? ?? '') ?? DateTime.now(),
      song: Song.fromMap(map['song'] as Map<String, dynamic>? ?? {}),
    );
  }
}
