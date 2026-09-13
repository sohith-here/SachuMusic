import 'dart:convert';

class Playlist {
  final String id;
  final String name;
  final List<String> songIds;
  final bool? _isPinned;

  bool get isPinned => _isPinned ?? false;

  const Playlist({
    required this.id,
    required this.name,
    this.songIds = const [],
    bool? isPinned,
  }) : _isPinned = isPinned ?? false;

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    bool? isPinned,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'songIds': songIds, 'isPinned': isPinned};
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled Playlist',
      songIds:
          (map['songIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Playlist.fromJson(String source) =>
      Playlist.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
