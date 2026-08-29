import 'package:flutter/foundation.dart';

class FavoritesService {
  FavoritesService._();

  static final FavoritesService instance = FavoritesService._();

  final Set<String> _favoriteSongIds = {};
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  bool isFavorite(String songId) {
    return _favoriteSongIds.contains(songId);
  }

  void toggleFavorite(String songId) {
    if (_favoriteSongIds.contains(songId)) {
      _favoriteSongIds.remove(songId);
    } else {
      _favoriteSongIds.add(songId);
    }
    changes.value++;
  }
}
