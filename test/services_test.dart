import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/services/favorites_service.dart';
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

  group('Windows platform persistence regression test', () {
    test('persists favorites and recently played through real Windows store', () async {
      FavoritesService.ensurePlatformInitialized();
      RecentlyPlayedService.ensurePlatformInitialized();

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

      // Simulate app restart: reset static completers and re-init
      SharedPreferences.resetStatic();

      final prefs = await SharedPreferences.getInstance();
      final reloadedFavs = prefs.getStringList('favorite_song_ids');
      expect(reloadedFavs, isNotNull);
      expect(reloadedFavs, contains(testFavoriteId));

      final reloadedRecent = prefs.getStringList('recently_played_songs');
      expect(reloadedRecent, isNotNull);
      expect(reloadedRecent!.any((item) => item.contains('Regression Title')), isTrue);
    });
  });
}
