import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

import '../models/playback_history_item.dart';
import '../models/song.dart';

class PlaybackHistoryService {
  PlaybackHistoryService._() {
    _init();
  }

  static final PlaybackHistoryService instance = PlaybackHistoryService._();

  static const String _storageKey = 'playback_history';
  static const int _maxEntries = 100;

  final List<PlaybackHistoryItem> _history = [];
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
    return _initFuture ??= _loadHistory();
  }

  Future<void> init() => _init();

  @visibleForTesting
  Future<void>? get lastSaveOperation => _saveFuture;

  @visibleForTesting
  void clearForTesting() {
    _history.clear();
    _initFuture = null;
    _saveFuture = null;
  }

  List<PlaybackHistoryItem> get history => List.unmodifiable(_history);

  bool get isEmpty => _history.isEmpty;

  int get count => _history.length;

  Future<void> _loadHistory() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey);
      _history.clear();
      if (jsonList != null && jsonList.isNotEmpty) {
        final loadedItems = <PlaybackHistoryItem>[];
        for (final item in jsonList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final historyItem = PlaybackHistoryItem.fromMap(map);
            if (historyItem.id.isNotEmpty || historyItem.song.id.isNotEmpty) {
              loadedItems.add(historyItem);
            }
          } catch (e) {
            debugPrint(
              'PlaybackHistoryService: Skipping corrupted history entry: $e',
            );
          }
        }
        _history.addAll(loadedItems.take(_maxEntries));
        changes.value++;
      }
    } catch (e) {
      debugPrint('PlaybackHistoryService: Error loading playback history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      ensurePlatformInitialized();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _history
          .take(_maxEntries)
          .map((item) => jsonEncode(item.toMap()))
          .toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      debugPrint('PlaybackHistoryService: Error saving playback history: $e');
    }
  }

  void recordPlayback(Song song, {DateTime? timestamp}) {
    final time = timestamp ?? DateTime.now();
    final entry = PlaybackHistoryItem(
      id: '${time.microsecondsSinceEpoch}_${song.id}',
      song: song,
      playedAt: time,
    );

    _history.insert(0, entry);

    if (_history.length > _maxEntries) {
      _history.removeRange(_maxEntries, _history.length);
    }

    changes.value++;
    _saveFuture = _saveHistory();
  }

  Future<void> clearHistory() async {
    _history.clear();
    changes.value++;
    _saveFuture = _saveHistory();
    await _saveFuture;
  }
}
