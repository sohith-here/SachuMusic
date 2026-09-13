class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? path;
  final Duration duration;
  final int? artworkId;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.path,
    required this.duration,
    this.artworkId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'path': path,
      'durationMs': duration.inMilliseconds,
      'artworkId': artworkId,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? 'Unknown artist',
      album: map['album'] as String? ?? 'Unknown album',
      path: map['path'] as String?,
      duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
      artworkId: map['artworkId'] as int?,
    );
  }
}
