import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

class FavoritesService {
  FavoritesService._() {
    _init();
  }

  static final FavoritesService instance = FavoritesService._();

  static const String _storageKey = 'favorite_song_ids';

  final Set<String> _favoriteSongIds = {};
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<void>? _initFuture;
  Future<void>? _saveFuture;

  static void ensurePlatformInitialized() {
    if (Platform.isWindows &&
        SharedPreferencesStorePlatform.instance is! InMemorySharedPreferencesStore) {
      PathProviderWindows.registerWith();
      SharedPreferencesWindows.registerWith();
    }
  }

  Future<void> _init() {
    return _initFuture ??= _loadFavorites();
  }

  Future<void> init() => _init();

  @visibleForTesting
  Future<void>? get lastSaveOperation => _saveFuture;

  @visibleForTesting
  void clearForTesting() {
    _favoriteSongIds.clear();
    _initFuture = null;
    _saveFuture = null;
  }

  Future<void> _loadFavorites() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_storageKey);
      _favoriteSongIds.clear();
      if (savedIds != null && savedIds.isNotEmpty) {
        _favoriteSongIds.addAll(savedIds);
        changes.value++;
      }
    } catch (e) {
      debugPrint('FavoritesService: Error loading favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _favoriteSongIds.toList());
    } catch (e) {
      debugPrint('FavoritesService: Error saving favorites: $e');
    }
  }

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
    _saveFuture = _saveFavorites();
  }
}
