import 'dart:convert';

class Playlist {
  final String id;
  final String name;
  final List<String> songIds;

  const Playlist({
    required this.id,
    required this.name,
    this.songIds = const [],
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songIds,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'songIds': songIds,
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled Playlist',
      songIds: (map['songIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Playlist.fromJson(String source) =>
      Playlist.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
