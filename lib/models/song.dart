class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? path;
  final Duration duration;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.path,
    required this.duration,
  });
}
