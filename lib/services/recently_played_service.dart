import 'package:flutter/foundation.dart';

import '../models/song.dart';

class RecentlyPlayedService {
  RecentlyPlayedService._();

  static final RecentlyPlayedService instance = RecentlyPlayedService._();

  final List<Song> _songs = [];

  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  List<Song> get songs => List.unmodifiable(_songs);

  void addSong(Song song) {
    _songs.removeWhere((item) => item.id == song.id);
    _songs.insert(0, song);

    if (_songs.length > 20) {
      _songs.removeLast();
    }

    changes.value++;
  }
}
