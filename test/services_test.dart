import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sachu_music/models/playlist.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/services/favorites_service.dart';
import 'package:sachu_music/services/playlist_service.dart';
import 'package:sachu_music/services/recently_played_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Song serialization', () {
    test('toMap and fromMap reconstruct Song correctly', () {
      const song = Song(
        id: 'song-1',
        title: 'Song One',
        artist: 'Artist One',
        album: 'Album One',
        path: '/path/to/song.mp3',
        duration: Duration(minutes: 3, seconds: 45),
        artworkId: 42,
      );

      final map = song.toMap();
      final restored = Song.fromMap(map);

      expect(restored.id, song.id);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.album, song.album);
      expect(restored.path, song.path);
      expect(restored.duration, song.duration);
      expect(restored.artworkId, song.artworkId);
    });

    test('fromMap handles missing or corrupted fields safely', () {
      final restored = Song.fromMap({});

      expect(restored.id, '');
      expect(restored.title, '');
      expect(restored.artist, 'Unknown artist');
      expect(restored.album, 'Unknown album');
      expect(restored.path, isNull);
      expect(restored.duration, Duration.zero);
      expect(restored.artworkId, isNull);
    });
  });

  group('FavoritesService persistence', () {
    setUp(() {
      FavoritesService.instance.clearForTesting();
    });

    test('FavoritesService loads persisted IDs and toggles', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_song_ids': ['fav-1', 'fav-2'],
      });

      final favorites = FavoritesService.instance;
      await favorites.init();

      expect(favorites.isFavorite('fav-1'), isTrue);
      expect(favorites.isFavorite('fav-2'), isTrue);
      expect(favorites.isFavorite('fav-3'), isFalse);

      favorites.toggleFavorite('fav-3');
      expect(favorites.isFavorite('fav-3'), isTrue);

      favorites.toggleFavorite('fav-1');
      expect(favorites.isFavorite('fav-1'), isFalse);
    });
  });

  group('RecentlyPlayedService persistence', () {
    setUp(() {
      RecentlyPlayedService.instance.clearForTesting();
    });

    test('RecentlyPlayedService manages order and enforces 20 songs limit', () async {
      SharedPreferences.setMockInitialValues({});

      final recent = RecentlyPlayedService.instance;
      await recent.init();

      const songA = Song(
        id: 'A',
        title: 'Song A',
        artist: 'Artist A',
        album: 'Album A',
        duration: Duration(minutes: 2),
      );
      const songB = Song(
        id: 'B',
        title: 'Song B',
        artist: 'Artist B',
        album: 'Album B',
        duration: Duration(minutes: 3),
      );

      recent.addSong(songA);
      expect(recent.songs.first.id, 'A');

      recent.addSong(songB);
      expect(recent.songs.first.id, 'B');
      expect(recent.songs.length, 2);

      // Re-adding songA moves it to the top
      recent.addSong(songA);
      expect(recent.songs.first.id, 'A');
      expect(recent.songs[1].id, 'B');
      expect(recent.songs.length, 2);

      // Add 25 songs to verify limit of 20
      for (int i = 0; i < 25; i++) {
        recent.addSong(
          Song(
            id: 'id-$i',
            title: 'Title $i',
            artist: 'Artist',
            album: 'Album',
            duration: Duration.zero,
          ),
        );
      }

      expect(recent.songs.length, 20);
      expect(recent.songs.first.id, 'id-24');
    });
  });

  group('Playlist model serialization', () {
    test('toMap and fromMap reconstruct Playlist correctly', () {
      const playlist = Playlist(
        id: 'pl-1',
        name: 'My Playlist',
        songIds: ['song-1', 'song-2'],
      );

      final map = playlist.toMap();
      final restored = Playlist.fromMap(map);

      expect(restored.id, playlist.id);
      expect(restored.name, playlist.name);
      expect(restored.songIds, playlist.songIds);
    });

    test('toJson and fromJson serialize and deserialize correctly', () {
      const playlist = Playlist(
        id: 'pl-2',
        name: 'Rock Classics',
        songIds: ['rock-1', 'rock-2', 'rock-3'],
      );

      final jsonStr = playlist.toJson();
      final restored = Playlist.fromJson(jsonStr);

      expect(restored.id, playlist.id);
      expect(restored.name, playlist.name);
      expect(restored.songIds, playlist.songIds);
    });

    test('copyWith works correctly', () {
      const playlist = Playlist(
        id: 'pl-3',
        name: 'Original',
        songIds: ['s1'],
      );

      final updated = playlist.copyWith(
        name: 'Updated',
        songIds: ['s1', 's2'],
      );

      expect(updated.id, 'pl-3');
      expect(updated.name, 'Updated');
      expect(updated.songIds, ['s1', 's2']);
    });
  });

  group('PlaylistService operations and persistence', () {
    setUp(() {
      PlaylistService.instance.clearForTesting();
    });

    test('creates playlist with trimmed name and default fallback', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PlaylistService.instance;
      await service.init();

      final pl1 = service.createPlaylist('  Favorites 2026  ');
      expect(pl1.name, 'Favorites 2026');
      expect(service.playlists.length, 1);

      final pl2 = service.createPlaylist('   ');
      expect(pl2.name, 'Untitled Playlist');
      expect(service.playlists.length, 2);
    });

    test('adds songs preserving insertion order and prevents duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PlaylistService.instance;
      await service.init();

      final pl = service.createPlaylist('Chill', id: 'pl-chill');
      expect(pl.songIds, isEmpty);

      final addedA = service.addSongToPlaylist('pl-chill', 'song-a');
      expect(addedA, isTrue);

      final addedB = service.addSongToPlaylist('pl-chill', 'song-b');
      expect(addedB, isTrue);

      // Duplicate song-a should be rejected
      final addedADup = service.addSongToPlaylist('pl-chill', 'song-a');
      expect(addedADup, isFalse);

      final updatedPl = service.getPlaylist('pl-chill')!;
      expect(updatedPl.songIds, ['song-a', 'song-b']);
    });

    test('addSongsToPlaylist batch adds songs, preserves order, and skips duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PlaylistService.instance;
      await service.init();

      service.createPlaylist('Roadtrip', id: 'pl-rt');
      service.addSongToPlaylist('pl-rt', 'song-1');

      // Add songs where 'song-1' is duplicate and 'song-2', 'song-3' are new
      final count = service.addSongsToPlaylist('pl-rt', ['song-1', 'song-2', 'song-3']);
      expect(count, 2);

      final updated = service.getPlaylist('pl-rt')!;
      expect(updated.songIds, ['song-1', 'song-2', 'song-3']);
    });

    test('removes song from playlist', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PlaylistService.instance;
      await service.init();

      service.createPlaylist('Workout', id: 'pl-workout');
      service.addSongToPlaylist('pl-workout', 'song-1');
      service.addSongToPlaylist('pl-workout', 'song-2');

      final removed = service.removeSongFromPlaylist('pl-workout', 'song-1');
      expect(removed, isTrue);

      final notRemoved =
          service.removeSongFromPlaylist('pl-workout', 'song-nonexistent');
      expect(notRemoved, isFalse);

      final updated = service.getPlaylist('pl-workout')!;
      expect(updated.songIds, ['song-2']);
    });

    test('deletes playlist', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PlaylistService.instance;
      await service.init();

      service.createPlaylist('ToDelete', id: 'pl-del');
      expect(service.playlists.length, 1);

      final deleted = service.deletePlaylist('pl-del');
      expect(deleted, isTrue);
      expect(service.playlists, isEmpty);

      final deleteAgain = service.deletePlaylist('pl-del');
      expect(deleteAgain, isFalse);
    });

    test('persists and reloads playlists across service restart', () async {
      const plJson =
          '{"id":"pl-persisted","name":"Road Trip","songIds":["rt-1","rt-2"]}';
      SharedPreferences.setMockInitialValues({
        'saved_playlists': [plJson],
      });

      final service = PlaylistService.instance;
      await service.init();

      expect(service.playlists.length, 1);
      final pl = service.getPlaylist('pl-persisted')!;
      expect(pl.name, 'Road Trip');
      expect(pl.songIds, ['rt-1', 'rt-2']);
    });
  });

  group('Windows platform persistence regression test', () {
    test('persists favorites and recently played through real Windows store', () async {
      FavoritesService.ensurePlatformInitialized();
      RecentlyPlayedService.ensurePlatformInitialized();
      PlaylistService.ensurePlatformInitialized();

      // Reset static state to ensure we test real platform store
      SharedPreferences.resetStatic();

      final favorites = FavoritesService.instance;
      await favorites.init();

      const testFavoriteId = 'C:\\Music\\RegressionTestSong.mp3';
      if (!favorites.isFavorite(testFavoriteId)) {
        favorites.toggleFavorite(testFavoriteId);
      }
      await favorites.lastSaveOperation;
      expect(favorites.isFavorite(testFavoriteId), isTrue);

      final recent = RecentlyPlayedService.instance;
      await recent.init();

      const testSong = Song(
        id: testFavoriteId,
        title: 'Regression Title',
        artist: 'Regression Artist',
        album: 'Regression Album',
        path: testFavoriteId,
        duration: Duration(minutes: 4),
      );
      recent.addSong(testSong);
      await recent.lastSaveOperation;

      final playlistService = PlaylistService.instance;
      await playlistService.init();

      playlistService.createPlaylist('Windows Playlist', id: 'win-pl-1');
      playlistService.addSongToPlaylist('win-pl-1', testFavoriteId);
      await playlistService.lastSaveOperation;

      // Simulate app restart: reset static completers and re-init
      SharedPreferences.resetStatic();

      final prefs = await SharedPreferences.getInstance();
      final reloadedFavs = prefs.getStringList('favorite_song_ids');
      expect(reloadedFavs, isNotNull);
      expect(reloadedFavs, contains(testFavoriteId));

      final reloadedRecent = prefs.getStringList('recently_played_songs');
      expect(reloadedRecent, isNotNull);
      expect(
        reloadedRecent!.any((item) => item.contains('Regression Title')),
        isTrue,
      );

      final reloadedPlaylists = prefs.getStringList('saved_playlists');
      expect(reloadedPlaylists, isNotNull);
      expect(
        reloadedPlaylists!.any((item) => item.contains('Windows Playlist')),
        isTrue,
      );
    });
  });
}
