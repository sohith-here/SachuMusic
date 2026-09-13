import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

import '../models/song.dart';

class RecentlyPlayedService {
  RecentlyPlayedService._() {
    _init();
  }

  static final RecentlyPlayedService instance = RecentlyPlayedService._();

  static const String _storageKey = 'recently_played_songs';
  static const int _maxSongs = 20;

  final List<Song> _songs = [];
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
    return _initFuture ??= _loadSongs();
  }

  Future<void> init() => _init();

  @visibleForTesting
  Future<void>? get lastSaveOperation => _saveFuture;

  @visibleForTesting
  void clearForTesting() {
    _songs.clear();
    _initFuture = null;
    _saveFuture = null;
  }

  List<Song> get songs => List.unmodifiable(_songs);

  Future<void> _loadSongs() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey);
      _songs.clear();
      if (jsonList != null && jsonList.isNotEmpty) {
        final loadedSongs = <Song>[];
        for (final item in jsonList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final song = Song.fromMap(map);
            if (song.id.isNotEmpty) {
              loadedSongs.add(song);
            }
          } catch (e) {
            debugPrint('RecentlyPlayedService: Skipping corrupted song entry: $e');
          }
        }
        _songs.addAll(loadedSongs.take(_maxSongs));
        changes.value++;
      }
    } catch (e) {
      debugPrint('RecentlyPlayedService: Error loading recently played: $e');
    }
  }

  Future<void> _saveSongs() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _songs.map((song) => jsonEncode(song.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      debugPrint('RecentlyPlayedService: Error saving recently played: $e');
    }
  }

  void addSong(Song song) {
    _songs.removeWhere((item) => item.id == song.id);
    _songs.insert(0, song);

    if (_songs.length > _maxSongs) {
      _songs.removeLast();
    }

    changes.value++;
    _saveFuture = _saveSongs();
  }
}
