import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

import '../models/playlist.dart';

class PlaylistService {
  PlaylistService._() {
    _init();
  }

  static final PlaylistService instance = PlaylistService._();

  static const String _storageKey = 'saved_playlists';

  final List<Playlist> _playlists = [];
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<void>? _initFuture;
  Future<void>? _saveFuture;

  static void ensurePlatformInitialized() {
    if (Platform.isWindows &&
        SharedPreferencesStorePlatform.instance
            is! InMemorySharedPreferencesStore) {
      PathProviderWindows.registerWith();
      SharedPreferencesWindows.registerWith();
    }
  }

  Future<void> _init() {
    return _initFuture ??= _loadPlaylists();
  }

  Future<void> init() => _init();

  @visibleForTesting
  Future<void>? get lastSaveOperation => _saveFuture;

  @visibleForTesting
  void clearForTesting() {
    _playlists.clear();
    _initFuture = null;
    _saveFuture = null;
  }

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Playlist? getPlaylist(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey);
      _playlists.clear();
      if (jsonList != null && jsonList.isNotEmpty) {
        for (final item in jsonList) {
          try {
            final playlist = Playlist.fromJson(item);
            if (playlist.id.isNotEmpty) {
              _playlists.add(playlist);
            }
          } catch (e) {
            debugPrint(
              'PlaylistService: Skipping corrupted playlist entry: $e',
            );
          }
        }
        changes.value++;
      }
    } catch (e) {
      debugPrint('PlaylistService: Error loading playlists: $e');
    }
  }

  Future<void> _savePlaylists() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _playlists.map((p) => p.toJson()).toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      debugPrint('PlaylistService: Error saving playlists: $e');
    }
  }

  Playlist createPlaylist(String name, {String? id}) {
    final trimmedName = name.trim().isEmpty ? 'Untitled Playlist' : name.trim();
    final newPlaylist = Playlist(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmedName,
      songIds: const [],
    );
    _playlists.add(newPlaylist);
    changes.value++;
    _saveFuture = _savePlaylists();
    return newPlaylist;
  }

  bool deletePlaylist(String playlistId) {
    final initialLength = _playlists.length;
    _playlists.removeWhere((p) => p.id == playlistId);
    if (_playlists.length != initialLength) {
      changes.value++;
      _saveFuture = _savePlaylists();
      return true;
    }
    return false;
  }

  bool renamePlaylist(String playlistId, String newName) {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) return false;

    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];
    if (playlist.name == trimmedName) return true;

    _playlists[index] = playlist.copyWith(name: trimmedName);
    changes.value++;
    _saveFuture = _savePlaylists();
    return true;
  }

  bool addSongToPlaylist(String playlistId, String songId) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];
    if (playlist.songIds.contains(songId)) {
      return false;
    }

    final updatedSongs = List<String>.from(playlist.songIds)..add(songId);
    _playlists[index] = playlist.copyWith(songIds: updatedSongs);
    changes.value++;
    _saveFuture = _savePlaylists();
    return true;
  }

  int addSongsToPlaylist(String playlistId, List<String> songIds) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return 0;

    final playlist = _playlists[index];
    final updatedSongs = List<String>.from(playlist.songIds);
    int addedCount = 0;

    for (final songId in songIds) {
      if (!updatedSongs.contains(songId)) {
        updatedSongs.add(songId);
        addedCount++;
      }
    }

    if (addedCount > 0) {
      _playlists[index] = playlist.copyWith(songIds: updatedSongs);
      changes.value++;
      _saveFuture = _savePlaylists();
    }

    return addedCount;
  }

  bool removeSongFromPlaylist(String playlistId, String songId) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];
    if (!playlist.songIds.contains(songId)) {
      return false;
    }

    final updatedSongs = List<String>.from(playlist.songIds)..remove(songId);
    _playlists[index] = playlist.copyWith(songIds: updatedSongs);
    changes.value++;
    _saveFuture = _savePlaylists();
    return true;
  }

  bool reorderSong(String playlistId, int oldIndex, int newIndex) {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];
    if (oldIndex < 0 ||
        oldIndex >= playlist.songIds.length ||
        newIndex < 0 ||
        newIndex >= playlist.songIds.length) {
      return false;
    }

    if (oldIndex == newIndex) {
      return true;
    }

    final updatedSongs = List<String>.from(playlist.songIds);
    final songId = updatedSongs.removeAt(oldIndex);
    updatedSongs.insert(newIndex, songId);

    _playlists[index] = playlist.copyWith(songIds: updatedSongs);
    changes.value++;
    _saveFuture = _savePlaylists();
    return true;
  }
}
