import 'dart:io';

import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import 'music_repository.dart';

class LocalMusicRepository implements MusicRepository {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  Future<List<Song>> getSongs() async {
    if (Platform.isAndroid) {
      return _getAndroidSongs();
    }

    if (Platform.isWindows) {
      return _getWindowsSongs();
    }

    return [];
  }

  // ============================================================
  // ANDROID
  // ============================================================

  Future<List<Song>> _getAndroidSongs() async {
    final hasPermission = await _audioQuery.permissionsStatus();

    if (!hasPermission) {
      final granted = await _audioQuery.permissionsRequest();

      if (!granted) {
        return [];
      }
    }

    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return songs.map((song) {
      return Song(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? 'Unknown artist',
        album: song.album ?? 'Unknown album',
        path: song.data,
        duration: Duration(milliseconds: song.duration ?? 0),
      );
    }).toList();
  }

  // ============================================================
  // WINDOWS
  // ============================================================

  Future<List<Song>> _getWindowsSongs() async {
    final userProfile = Platform.environment['USERPROFILE'];

    if (userProfile == null || userProfile.isEmpty) {
      return [];
    }

    final musicDirectory = Directory('$userProfile\\Music');

    if (!await musicDirectory.exists()) {
      return [];
    }

    final songs = <Song>[];

    await for (final entity in musicDirectory.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }

      final extension = entity.path.split('.').last.toLowerCase();

      if (!_isAudioFile(extension)) {
        continue;
      }

      final fileName = entity.path.split(Platform.pathSeparator).last;

      final title = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      songs.add(
        Song(
          id: entity.path,
          title: title,
          artist: 'Unknown artist',
          album: 'Unknown album',
          path: entity.path,
          duration: Duration.zero,
        ),
      );
    }

    songs.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    return songs;
  }

  bool _isAudioFile(String extension) {
    const supportedFormats = {
      'mp3',
      'wav',
      'm4a',
      'aac',
      'flac',
      'ogg',
      'opus',
    };

    return supportedFormats.contains(extension);
  }
}
