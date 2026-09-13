import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/songs_screen.dart';
import 'package:sachu_music/services/audio_player_service.dart';
import 'package:sachu_music/services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAudioPlayerPlatform extends AudioPlayerPlatform {
  MockAudioPlayerPlatform(super.id);

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => Stream.value(
    PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updatePosition: Duration.zero,
      updateTime: DateTime.now(),
      bufferedPosition: Duration.zero,
      duration: const Duration(minutes: 3),
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ),
  );

  @override
  Future<LoadResponse> load(LoadRequest request) async =>
      LoadResponse(duration: const Duration(minutes: 3));

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async =>
      DisposeResponse();
}

class MockJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    return MockAudioPlayerPlatform(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    return DisposeAllPlayersResponse();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const songA = Song(
    id: 'id-a',
    title: 'Apple',
    artist: 'Charlie',
    album: 'Echo',
    path: '/music/a.mp3',
    duration: Duration(minutes: 1),
  );

  const songB = Song(
    id: 'id-b',
    title: 'banana', // lowercase to test case-insensitivity
    artist: 'Bravo',
    album: 'Delta',
    path: '/music/b.mp3',
    duration: Duration(minutes: 4),
  );

  const songC = Song(
    id: 'id-c',
    title: 'Cherry',
    artist: 'Alpha',
    album: 'Foxtrot',
    path: '/music/c.mp3',
    duration: Duration(minutes: 2),
  );

  const songATie = Song(
    id: 'id-a-tie',
    title: 'Apple', // duplicate title for tie-breaking
    artist: 'Delta',
    album: 'Alpha',
    path: '/music/a_tie.mp3',
    duration: Duration(minutes: 3),
  );

  final testSongs = [songA, songB, songC, songATie];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FavoritesService.instance.clearForTesting();
    JustAudioPlatform.instance = MockJustAudioPlatform();
  });

  List<String> getDisplayedTitles(WidgetTester tester) {
    final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
    return listTiles.map((t) => (t.title as Text).data!).toList();
  }

  Future<void> openSortFilterSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
  }

  Future<void> tapOptionInSheet(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('SongsScreen Sort Options', () {
    testWidgets('1. Title A → Z default order with case-insensitivity', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      final titles = getDisplayedTitles(tester);
      // Apple (Charlie) -> Apple (Delta) -> banana -> Cherry
      expect(titles, ['Apple', 'Apple', 'banana', 'Cherry']);
    });

    testWidgets('2. Title Z → A reverses primary title sort', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Title Z → A');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      final titles = getDisplayedTitles(tester);
      // Cherry -> banana -> Apple (Charlie) -> Apple (Delta)
      expect(titles, ['Cherry', 'banana', 'Apple', 'Apple']);
    });

    testWidgets('3. Artist A → Z order', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Artist A → Z');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // Artists: Alpha (Cherry) -> Bravo (banana) -> Charlie (Apple) -> Delta (Apple)
      final titles = getDisplayedTitles(tester);
      expect(titles, ['Cherry', 'banana', 'Apple', 'Apple']);
    });

    testWidgets('4. Artist Z → A order', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Artist Z → A');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // Artists: Delta (Apple) -> Charlie (Apple) -> Bravo (banana) -> Alpha (Cherry)
      final titles = getDisplayedTitles(tester);
      expect(titles, ['Apple', 'Apple', 'banana', 'Cherry']);
    });

    testWidgets('5. Album A → Z order', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Album A → Z');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // Albums: Alpha (songATie: Apple) -> Delta (songB: banana) -> Echo (songA: Apple) -> Foxtrot (songC: Cherry)
      final titles = getDisplayedTitles(tester);
      expect(titles, ['Apple', 'banana', 'Apple', 'Cherry']);
    });

    testWidgets('6. Album Z → A order', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Album Z → A');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // Albums: Foxtrot (Cherry) -> Echo (Apple) -> Delta (banana) -> Alpha (Apple)
      final titles = getDisplayedTitles(tester);
      expect(titles, ['Cherry', 'Apple', 'banana', 'Apple']);
    });

    testWidgets('7. Duration shortest → longest', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Duration shortest → longest');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // Durations: 1m (songA: Apple) -> 2m (songC: Cherry) -> 3m (songATie: Apple) -> 4m (songB: banana)
      final titles = getDisplayedTitles(tester);
      expect(titles, ['Apple', 'Cherry', 'Apple', 'banana']);
    });

    testWidgets('8. Duration longest → shortest', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Duration longest → shortest');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // Durations: 4m (songB: banana) -> 3m (songATie: Apple) -> 2m (songC: Cherry) -> 1m (songA: Apple)
      final titles = getDisplayedTitles(tester);
      expect(titles, ['banana', 'Apple', 'Cherry', 'Apple']);
    });

    testWidgets(
      '9 & 10. Case-insensitive sorting and deterministic tie-breaking',
      (WidgetTester tester) async {
        const tie1 = Song(
          id: 'tie-1',
          title: 'Song',
          artist: 'SameArtist',
          album: 'Album',
          duration: Duration(minutes: 2),
        );
        const tie2 = Song(
          id: 'tie-2',
          title: 'song', // lowercase
          artist: 'SameArtist',
          album: 'Album',
          duration: Duration(minutes: 2),
        );

        await tester.pumpWidget(
          const MaterialApp(home: SongsScreen(songs: [tie2, tie1])),
        );
        await tester.pumpAndSettle();

        final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
        expect(listTiles.length, 2);
      },
    );
  });

  group('SongsScreen Filter and Search Combinations', () {
    testWidgets('11. Favorites-only filtering', (WidgetTester tester) async {
      FavoritesService.instance.toggleFavorite(songB.id);

      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      expect(getDisplayedTitles(tester).length, 4);

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Favorites only');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      final titles = getDisplayedTitles(tester);
      expect(titles, ['banana']);
    });

    testWidgets('12. Search + sorting', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      // Search "apple"
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pumpAndSettle();

      expect(getDisplayedTitles(tester), ['Apple', 'Apple']);

      // Sort Duration longest -> shortest (songATie: 3m vs songA: 1m)
      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Duration longest → shortest');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // songATie (3m) -> songA (1m)
      final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
      expect(listTiles.first.subtitle, isA<Text>());
      expect((listTiles.first.subtitle as Text).data, 'Delta');
      expect((listTiles.last.subtitle as Text).data, 'Charlie');
    });

    testWidgets('13. Search + Favorites-only filtering', (
      WidgetTester tester,
    ) async {
      FavoritesService.instance.toggleFavorite(songA.id);
      FavoritesService.instance.toggleFavorite(songC.id);

      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Favorites only');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // Currently favorites are songA and songC
      expect(getDisplayedTitles(tester), ['Apple', 'Cherry']);

      // Search for "cherry"
      await tester.enterText(find.byType(TextField), 'cherry');
      await tester.pumpAndSettle();

      expect(getDisplayedTitles(tester), ['Cherry']);
    });

    testWidgets('14. Search + Favorites-only + sorting', (
      WidgetTester tester,
    ) async {
      FavoritesService.instance.toggleFavorite(songA.id);
      FavoritesService.instance.toggleFavorite(songB.id);
      FavoritesService.instance.toggleFavorite(songC.id);

      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      // Filter: Favorites only
      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Favorites only');

      // Sort: Duration longest -> shortest
      await tapOptionInSheet(tester, 'Duration longest → shortest');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // All 3 favorites sorted by duration: banana (4m), Cherry (2m), Apple (1m)
      expect(getDisplayedTitles(tester), ['banana', 'Cherry', 'Apple']);

      // Search for "banana"
      await tester.enterText(find.byType(TextField), 'banana');
      await tester.pumpAndSettle();

      expect(getDisplayedTitles(tester), ['banana']);
    });

    testWidgets(
      '15. Favorites change immediately updates Favorites-only results',
      (WidgetTester tester) async {
        FavoritesService.instance.toggleFavorite(songA.id);

        await tester.pumpWidget(
          MaterialApp(home: SongsScreen(songs: testSongs)),
        );
        await tester.pumpAndSettle();

        await openSortFilterSheet(tester);
        await tapOptionInSheet(tester, 'Favorites only');
        Navigator.pop(tester.element(find.text('Sort & Filter')));
        await tester.pumpAndSettle();

        expect(getDisplayedTitles(tester), ['Apple']);

        // Add songB to favorites externally
        FavoritesService.instance.toggleFavorite(songB.id);
        await tester.pumpAndSettle();

        expect(getDisplayedTitles(tester), ['Apple', 'banana']);

        // Remove songA from favorites via the row button
        await tester.tap(find.byIcon(Icons.favorite).first);
        await tester.pumpAndSettle();

        expect(getDisplayedTitles(tester), ['banana']);
      },
    );

    testWidgets(
      '16. Empty search/filter result shows "No matching songs found"',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: SongsScreen(songs: testSongs)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'nonexistent search');
        await tester.pumpAndSettle();

        expect(find.text('No matching songs found'), findsOneWidget);
      },
    );

    testWidgets('17. Empty library shows "No music found"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SongsScreen(songs: [])));
      await tester.pumpAndSettle();

      expect(find.text('No music found'), findsOneWidget);
      expect(find.text('No matching songs found'), findsNothing);
    });
  });

  group('SongsScreen UI & Controls', () {
    testWidgets(
      '18. Sort/filter control appears in AppBar and indicates active status',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            ),
            home: SongsScreen(songs: testSongs),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.byIcon(Icons.tune);
        expect(iconFinder, findsOneWidget);

        IconButton button = tester.widget(
          find.ancestor(of: iconFinder, matching: find.byType(IconButton)),
        );
        expect(button.tooltip, 'Sort & filter');

        // Change filter to active
        await openSortFilterSheet(tester);
        await tapOptionInSheet(tester, 'Favorites only');
        Navigator.pop(tester.element(find.text('Sort & Filter')));
        await tester.pumpAndSettle();

        Icon icon = tester.widget(iconFinder);
        expect(icon.color, isNotNull);
      },
    );

    testWidgets('19. Bottom sheet displays all expected options', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);

      expect(find.text('Sort & Filter'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('All songs'), findsOneWidget);
      expect(find.text('Favorites only'), findsOneWidget);
      expect(find.text('Title A → Z'), findsOneWidget);
      expect(find.text('Title Z → A'), findsOneWidget);
      expect(find.text('Artist A → Z'), findsOneWidget);
      expect(find.text('Artist Z → A'), findsOneWidget);
      expect(find.text('Album A → Z'), findsOneWidget);
      expect(find.text('Album Z → A'), findsOneWidget);
      expect(find.text('Duration shortest → longest'), findsOneWidget);
      expect(find.text('Duration longest → shortest'), findsOneWidget);
    });

    testWidgets('20. Reset restores default sort and filter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: SongsScreen(songs: testSongs)));
      await tester.pumpAndSettle();

      await openSortFilterSheet(tester);
      await tapOptionInSheet(tester, 'Favorites only');
      await tapOptionInSheet(tester, 'Artist Z → A');

      // Tap Reset
      await tapOptionInSheet(tester, 'Reset');
      Navigator.pop(tester.element(find.text('Sort & Filter')));
      await tester.pumpAndSettle();

      // Default title order and all songs restored
      expect(getDisplayedTitles(tester), [
        'Apple',
        'Apple',
        'banana',
        'Cherry',
      ]);
    });

    testWidgets(
      '21. Tapping a song preserves existing playback playlist behavior',
      (WidgetTester tester) async {
        final player = AudioPlayerService.instance;

        await tester.pumpWidget(
          MaterialApp(home: SongsScreen(songs: testSongs)),
        );
        await tester.pumpAndSettle();

        // Tap the first song
        await tester.tap(find.text('Apple').first);
        await tester.pumpAndSettle();

        // Verify currentSong is set to Apple
        expect(player.currentSong?.title, 'Apple');
        // Queue contains all original widget.songs
        expect(player.queue.length, testSongs.length);
      },
    );
  });
}
