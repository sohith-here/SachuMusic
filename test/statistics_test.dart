import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/home_screen.dart';
import 'package:sachu_music/screens/statistics_screen.dart';
import 'package:sachu_music/services/favorites_service.dart';
import 'package:sachu_music/services/playback_history_service.dart';
import 'package:sachu_music/services/playlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const song1 = Song(
    id: 's1',
    title: 'Song One',
    artist: 'Artist One',
    album: 'Album One',
    duration: Duration(minutes: 3, seconds: 30),
  );

  const song2 = Song(
    id: 's2',
    title: 'Song Two',
    artist: 'Artist Two',
    album: 'Album Two',
    duration: Duration(minutes: 4, seconds: 15),
  );

  const song3 = Song(
    id: 's3',
    title: 'Song Three',
    artist: 'Artist Three',
    album: 'Album Three',
    duration: Duration(minutes: 2, seconds: 15),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FavoritesService.instance.clearForTesting();
    PlaylistService.instance.clearForTesting();
    PlaybackHistoryService.instance.clearForTesting();
  });

  group('Duration Formatting (1 to 6)', () {
    test('1. formatTotalDuration(Duration.zero) → "0m"', () {
      expect(formatTotalDuration(Duration.zero), '0m');
      expect(formatTotalDuration(const Duration(seconds: -10)), '0m');
    });

    test('2. 30 seconds → "< 1m"', () {
      expect(formatTotalDuration(const Duration(seconds: 30)), '< 1m');
      expect(formatTotalDuration(const Duration(seconds: 59)), '< 1m');
    });

    test('3. 45 minutes → "45m"', () {
      expect(formatTotalDuration(const Duration(minutes: 45)), '45m');
      expect(formatTotalDuration(const Duration(minutes: 1)), '1m');
    });

    test('4. 2h 15m → "2h 15m"', () {
      expect(
        formatTotalDuration(const Duration(hours: 2, minutes: 15)),
        '2h 15m',
      );
      // Exactly 2 hours omits "0m"
      expect(formatTotalDuration(const Duration(hours: 2)), '2h');
    });

    test('5. 24h → "1d"', () {
      expect(formatTotalDuration(const Duration(hours: 24)), '1d');
    });

    test('6. 28h → "1d 4h"', () {
      expect(formatTotalDuration(const Duration(hours: 28)), '1d 4h');
      expect(
        formatTotalDuration(const Duration(days: 2, hours: 5, minutes: 30)),
        '2d 5h',
      );
    });
  });

  group('Statistics Calculations (7 to 14)', () {
    test('7 & 8. Library song count and total duration', () {
      final songs = [song1, song2, song3];
      final totalSongs = songs.length;
      final totalDuration = songs.fold<Duration>(
        Duration.zero,
        (prev, s) => prev + s.duration,
      );

      expect(totalSongs, 3);
      // 3m30s + 4m15s + 2m15s = 10 minutes
      expect(totalDuration, const Duration(minutes: 10));
      expect(formatTotalDuration(totalDuration), '10m');
    });

    test('9. Favorite count for valid library songs', () {
      final songs = [song1, song2, song3];
      final favorites = FavoritesService.instance;

      favorites.toggleFavorite(song1.id);
      favorites.toggleFavorite(song3.id);
      favorites.toggleFavorite('orphaned-id'); // Not in library

      final favoriteCount = songs
          .where((s) => favorites.isFavorite(s.id))
          .length;
      expect(favoriteCount, 2);
    });

    test('10 & 11. Playlist count and total songs across playlists', () {
      final playlistService = PlaylistService.instance;

      playlistService.createPlaylist('Pl 1', id: 'p1');
      playlistService.createPlaylist('Pl 2', id: 'p2');
      playlistService.addSongToPlaylist('p1', 's1');
      playlistService.addSongToPlaylist('p1', 's2');
      playlistService.addSongToPlaylist('p2', 's2');
      playlistService.addSongToPlaylist('p2', 's3');
      playlistService.addSongToPlaylist('p2', 's4');

      final playlists = playlistService.playlists.length;
      final totalSongsInPlaylists = playlistService.playlists.fold<int>(
        0,
        (prev, p) => prev + p.songIds.length,
      );

      expect(playlists, 2);
      expect(totalSongsInPlaylists, 5);
    });

    test('12 & 13. History entry count and total duration sum', () {
      final historyService = PlaybackHistoryService.instance;

      historyService.recordPlayback(song1);
      historyService.recordPlayback(song2);
      historyService.recordPlayback(song1); // 2nd play of song1

      final recordedPlays = historyService.count;
      final totalListening = historyService.history.fold<Duration>(
        Duration.zero,
        (prev, item) => prev + item.song.duration,
      );

      expect(recordedPlays, 3);
      // 3m30s + 4m15s + 3m30s = 11m 15s
      expect(totalListening, const Duration(minutes: 11, seconds: 15));
      expect(formatTotalDuration(totalListening), '11m');
    });

    test('14. Empty library, history, and playlists handle safely', () {
      final emptySongs = <Song>[];
      final totalSongs = emptySongs.length;
      final totalDuration = emptySongs.fold<Duration>(
        Duration.zero,
        (prev, s) => prev + s.duration,
      );

      expect(totalSongs, 0);
      expect(totalDuration, Duration.zero);
      expect(formatTotalDuration(totalDuration), '0m');
    });
  });

  group('Widget Tests (15 to 17)', () {
    testWidgets(
      '15 & 16. All four sections and expected statistic values render',
      (WidgetTester tester) async {
        final songs = [song1, song2, song3];

        FavoritesService.instance.toggleFavorite(song1.id);
        FavoritesService.instance.toggleFavorite(song2.id);

        PlaylistService.instance.createPlaylist('Roadtrip', id: 'pl-1');
        PlaylistService.instance.addSongToPlaylist('pl-1', song1.id);
        PlaylistService.instance.addSongToPlaylist('pl-1', song2.id);

        PlaybackHistoryService.instance.recordPlayback(song1);
        PlaybackHistoryService.instance.recordPlayback(song2);

        await tester.pumpWidget(
          MaterialApp(home: StatisticsScreen(songs: songs)),
        );
        await tester.pumpAndSettle();

        // Check section titles
        expect(find.text('Library'), findsOneWidget);
        expect(find.text('Favorites'), findsOneWidget);
        expect(
          find.text('Playlists'),
          findsNWidgets(2),
        ); // Card title & metric label
        expect(find.text('Listening History'), findsOneWidget);

        // Check metric labels
        expect(find.text('Total Songs'), findsOneWidget);
        expect(find.text('Total Library Duration'), findsOneWidget);
        expect(find.text('Favorite Songs'), findsOneWidget);
        expect(find.text('Songs in Playlists'), findsOneWidget);
        expect(find.text('Recorded Plays'), findsOneWidget);
        expect(find.text('Total Listening Time'), findsOneWidget);

        // Check values within specific cards
        final libCard = find.widgetWithText(Card, 'Library');
        expect(
          find.descendant(of: libCard, matching: find.text('3')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: libCard, matching: find.text('10m')),
          findsOneWidget,
        );

        final favCard = find.widgetWithText(Card, 'Favorites');
        expect(
          find.descendant(of: favCard, matching: find.text('2')),
          findsOneWidget,
        );

        final plCard = find.widgetWithText(Card, 'Playlists');
        expect(
          find.descendant(of: plCard, matching: find.text('1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: plCard, matching: find.text('2')),
          findsOneWidget,
        );

        final histCard = find.widgetWithText(Card, 'Listening History');
        expect(
          find.descendant(of: histCard, matching: find.text('2')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: histCard, matching: find.text('7m')),
          findsOneWidget,
        );
      },
    );

    testWidgets('17. Empty-state values render cleanly without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: StatisticsScreen(songs: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
      expect(find.text('0m'), findsNWidgets(2)); // Library & Listening duration
    });
  });

  group('Reactivity Tests (18 to 20)', () {
    testWidgets('18. Favorite change updates favorite count immediately', (
      WidgetTester tester,
    ) async {
      final songs = [song1, song2];

      await tester.pumpWidget(
        MaterialApp(home: StatisticsScreen(songs: songs)),
      );
      await tester.pumpAndSettle();

      final favCard = find.widgetWithText(Card, 'Favorites');

      // Initial: 0 favorites
      expect(
        find.descendant(of: favCard, matching: find.text('0')),
        findsOneWidget,
      );

      // Add a favorite
      FavoritesService.instance.toggleFavorite(song1.id);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: favCard, matching: find.text('1')),
        findsOneWidget,
      );

      // Add another favorite
      FavoritesService.instance.toggleFavorite(song2.id);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: favCard, matching: find.text('2')),
        findsOneWidget,
      );

      // Remove a favorite
      FavoritesService.instance.toggleFavorite(song1.id);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: favCard, matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('19. Playlist change updates playlist statistics immediately', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: StatisticsScreen(songs: [song1, song2])),
      );
      await tester.pumpAndSettle();

      final plCard = find.widgetWithText(Card, 'Playlists');

      // Create playlist
      PlaylistService.instance.createPlaylist('Chill', id: 'ch-1');
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: plCard, matching: find.text('1')),
        findsOneWidget,
      ); // 1 playlist

      // Add songs
      PlaylistService.instance.addSongToPlaylist('ch-1', song1.id);
      PlaylistService.instance.addSongToPlaylist('ch-1', song2.id);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: plCard, matching: find.text('2')),
        findsOneWidget,
      ); // 2 songs in playlists
    });

    testWidgets('20. History change updates history statistics immediately', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: StatisticsScreen(songs: [song1])),
      );
      await tester.pumpAndSettle();

      final histCard = find.widgetWithText(Card, 'Listening History');

      // Record a play
      PlaybackHistoryService.instance.recordPlayback(song1);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: histCard, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: histCard, matching: find.text('3m')),
        findsOneWidget,
      );

      // Clear history
      await PlaybackHistoryService.instance.clearHistory();
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: histCard, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: histCard, matching: find.text('0m')),
        findsOneWidget,
      );
    });
  });

  group('Navigation (21 & 22)', () {
    testWidgets(
      '21 & 22. HomeScreen has Statistics tile and tapping opens StatisticsScreen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();

        // Check tile exists
        final tileFinder = find.widgetWithText(ListTile, 'Statistics');
        expect(tileFinder, findsOneWidget);
        expect(find.text('Library & listening overview'), findsOneWidget);
        expect(find.byIcon(Icons.insights), findsOneWidget);

        // Tap tile
        await tester.tap(tileFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Navigated to StatisticsScreen
        expect(find.byType(StatisticsScreen), findsOneWidget);
        expect(find.text('Statistics'), findsOneWidget);
        expect(find.text('Library'), findsOneWidget);
      },
    );
  });
}
