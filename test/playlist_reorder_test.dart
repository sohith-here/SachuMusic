import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/playlist_detail_screen.dart';
import 'package:sachu_music/services/audio_player_service.dart';
import 'package:sachu_music/services/playlist_service.dart';
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
    id: 'song-a',
    title: 'Song Alpha',
    artist: 'Artist A',
    album: 'Album A',
    path: '/music/song_a.mp3',
    duration: Duration(minutes: 3),
    artworkId: 101,
  );

  const songB = Song(
    id: 'song-b',
    title: 'Song Beta',
    artist: 'Artist B',
    album: 'Album B',
    path: '/music/song_b.mp3',
    duration: Duration(minutes: 4),
    artworkId: 202,
  );

  const songC = Song(
    id: 'song-c',
    title: 'Song Gamma',
    artist: 'Artist C',
    album: 'Album C',
    path: '/music/song_c.mp3',
    duration: Duration(minutes: 2),
    artworkId: null,
  );

  const songD = Song(
    id: 'song-d',
    title: 'Song Delta',
    artist: 'Artist D',
    album: 'Album D',
    path: '/music/song_d.mp3',
    duration: Duration(minutes: 5),
    artworkId: 404,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PlaylistService.instance.clearForTesting();
    await PlaylistService.instance.init();
    JustAudioPlatform.instance = MockJustAudioPlatform();
  });

  group('PlaylistService Reorder Unit Tests (1 to 17)', () {
    test('1. Reorder first → last', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c']);

      final result = service.reorderSong('pl-1', 0, 2);

      expect(result, isTrue);
      expect(service.getPlaylist('pl-1')?.songIds, ['b', 'c', 'a']);
    });

    test('2. Reorder last → first', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c']);

      final result = service.reorderSong('pl-1', 2, 0);

      expect(result, isTrue);
      expect(service.getPlaylist('pl-1')?.songIds, ['c', 'a', 'b']);
    });

    test('3. Reorder middle → another middle position', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c', 'd']);

      final result = service.reorderSong('pl-1', 1, 2);

      expect(result, isTrue);
      expect(service.getPlaylist('pl-1')?.songIds, ['a', 'c', 'b', 'd']);
    });

    test('4. Same position returns true and is a true no-op', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c']);

      final changesBefore = service.changes.value;
      final result = service.reorderSong('pl-1', 1, 1);

      expect(result, isTrue);
      expect(service.changes.value, changesBefore);
      expect(service.getPlaylist('pl-1')?.songIds, ['a', 'b', 'c']);
    });

    test('5. Negative oldIndex rejected', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c']);

      final result = service.reorderSong('pl-1', -1, 1);

      expect(result, isFalse);
      expect(service.getPlaylist('pl-1')?.songIds, ['a', 'b', 'c']);
    });

    test('6. Negative newIndex rejected', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c']);

      final result = service.reorderSong('pl-1', 1, -1);

      expect(result, isFalse);
      expect(service.getPlaylist('pl-1')?.songIds, ['a', 'b', 'c']);
    });

    test('7. oldIndex out of bounds rejected', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c']);

      final result = service.reorderSong('pl-1', 3, 1);

      expect(result, isFalse);
      expect(service.getPlaylist('pl-1')?.songIds, ['a', 'b', 'c']);
    });

    test('8. newIndex out of bounds rejected', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c']);

      final result = service.reorderSong('pl-1', 1, 3);

      expect(result, isFalse);
      expect(service.getPlaylist('pl-1')?.songIds, ['a', 'b', 'c']);
    });

    test('9. Nonexistent playlist ID rejected', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b', 'c']);

      final result = service.reorderSong('nonexistent', 0, 1);

      expect(result, isFalse);
      expect(service.getPlaylist('pl-1')?.songIds, ['a', 'b', 'c']);
    });

    test('10. Playlist ID remains unchanged', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-fixed');
      service.addSongsToPlaylist('pl-fixed', ['a', 'b']);

      service.reorderSong('pl-fixed', 0, 1);

      expect(service.getPlaylist('pl-fixed')?.id, 'pl-fixed');
    });

    test('11. Playlist name remains unchanged', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Road Trip Jams', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b']);

      service.reorderSong('pl-1', 0, 1);

      expect(service.getPlaylist('pl-1')?.name, 'Road Trip Jams');
    });

    test('12. All song IDs remain present exactly once', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['x', 'y', 'z']);

      service.reorderSong('pl-1', 0, 2);

      final songs = service.getPlaylist('pl-1')!.songIds;
      expect(songs.length, 3);
      expect(songs.toSet(), {'x', 'y', 'z'});
    });

    test('13. Playlist remains in the same position in PlaylistService', () {
      final service = PlaylistService.instance;
      service.createPlaylist('First', id: 'pl-first');
      service.createPlaylist('Target', id: 'pl-target');
      service.createPlaylist('Third', id: 'pl-third');

      service.addSongsToPlaylist('pl-target', ['a', 'b', 'c']);
      service.reorderSong('pl-target', 0, 1);

      expect(service.playlists.map((p) => p.id).toList(), [
        'pl-first',
        'pl-target',
        'pl-third',
      ]);
    });

    test(
      '14. changes notifier increments exactly once on successful reorder',
      () {
        final service = PlaylistService.instance;
        service.createPlaylist('Favorites', id: 'pl-1');
        service.addSongsToPlaylist('pl-1', ['a', 'b']);

        final changesBefore = service.changes.value;
        service.reorderSong('pl-1', 0, 1);

        expect(service.changes.value, changesBefore + 1);
      },
    );

    test('15. Invalid reorder does not increment changes', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b']);

      final changesBefore = service.changes.value;
      service.reorderSong('pl-1', -1, 5);

      expect(service.changes.value, changesBefore);
    });

    test('16. Same-position reorder does not increment changes', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Favorites', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['a', 'b']);

      final changesBefore = service.changes.value;
      service.reorderSong('pl-1', 0, 0);

      expect(service.changes.value, changesBefore);
    });

    test(
      '17. Reordered order persists across SharedPreferences reload',
      () async {
        final service = PlaylistService.instance;
        service.createPlaylist('Persisted', id: 'pl-p');
        service.addSongsToPlaylist('pl-p', ['song-1', 'song-2', 'song-3']);

        service.reorderSong('pl-p', 0, 2); // -> ['song-2', 'song-3', 'song-1']
        await service.lastSaveOperation;

        service.clearForTesting();
        await service.init();

        final loaded = service.getPlaylist('pl-p');
        expect(loaded, isNotNull);
        expect(loaded!.songIds, ['song-2', 'song-3', 'song-1']);
      },
    );
  });

  group('PlaylistDetailScreen Reorder Widget Tests (18 to 26)', () {
    testWidgets('18. Drag handle is visible for playlist songs', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Test PL', id: 'pl-test');
      PlaylistService.instance.addSongsToPlaylist('pl-test', [
        'song-a',
        'song-b',
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-test',
            initialSongs: [songA, songB],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    });

    testWidgets('19. Existing remove button remains visible', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Test PL', id: 'pl-test');
      PlaylistService.instance.addSongsToPlaylist('pl-test', [
        'song-a',
        'song-b',
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-test',
            initialSongs: [songA, songB],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(2));
    });

    testWidgets('20. Existing song title/artist remains visible', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Test PL', id: 'pl-test');
      PlaylistService.instance.addSongsToPlaylist('pl-test', [
        'song-a',
        'song-b',
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-test',
            initialSongs: [songA, songB],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Song Alpha'), findsOneWidget);
      expect(find.text('Artist A'), findsOneWidget);
      expect(find.text('Song Beta'), findsOneWidget);
      expect(find.text('Artist B'), findsOneWidget);
    });

    testWidgets('21. Existing song tap behavior remains functional', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Test PL', id: 'pl-test');
      PlaylistService.instance.addSongsToPlaylist('pl-test', [
        'song-a',
        'song-b',
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-test',
            initialSongs: [songA, songB],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Song Beta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(AudioPlayerService.instance.currentSong?.id, 'song-b');
    });

    testWidgets('22. Reordering updates displayed song order', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Test PL', id: 'pl-test');
      PlaylistService.instance.addSongsToPlaylist('pl-test', [
        'song-a',
        'song-b',
        'song-c',
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-test',
            initialSongs: [songA, songB, songC],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Reorder: move song-a from 0 to 2
      PlaylistService.instance.reorderSong('pl-test', 0, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((tiles[0].title as Text).data, 'Song Beta');
      expect((tiles[1].title as Text).data, 'Song Gamma');
      expect((tiles[2].title as Text).data, 'Song Alpha');
    });

    testWidgets('23. Empty playlist preserves existing empty state', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Empty PL', id: 'pl-empty');

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-empty',
            initialSongs: [songA, songB],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No songs in this playlist'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('24. One-song playlist remains stable', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('One PL', id: 'pl-one');
      PlaylistService.instance.addSongToPlaylist('pl-one', 'song-a');

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-one',
            initialSongs: [songA],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Song Alpha'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);

      // Triggering same position is safe
      final result = PlaylistService.instance.reorderSong('pl-one', 0, 0);
      expect(result, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Song Alpha'), findsOneWidget);
    });

    testWidgets(
      '25. Play All after reorder uses the reordered first song/order',
      (WidgetTester tester) async {
        PlaylistService.instance.createPlaylist('Test PL', id: 'pl-test');
        PlaylistService.instance.addSongsToPlaylist('pl-test', [
          'song-a',
          'song-b',
          'song-d',
        ]);

        await tester.pumpWidget(
          const MaterialApp(
            home: PlaylistDetailScreen(
              playlistId: 'pl-test',
              initialSongs: [songA, songB, songD],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Move song-b (index 1) to index 0
        PlaylistService.instance.reorderSong('pl-test', 1, 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap "Play all"
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Current song should be Song Beta
        expect(AudioPlayerService.instance.currentSong?.id, 'song-b');
        // Queue should have song-b, song-a, song-d in that order
        expect(AudioPlayerService.instance.queue.map((s) => s.id).toList(), [
          'song-b',
          'song-a',
          'song-d',
        ]);
      },
    );

    testWidgets('26. Playlist artwork follows reordered songIds', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Artwork PL', id: 'pl-art');
      // songA has artwork 101, songB has artwork 202
      PlaylistService.instance.addSongsToPlaylist('pl-art', [
        'song-a',
        'song-b',
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-art',
            initialSongs: [songA, songB],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially, the header artwork is songA (101)
      final artworkFinders = find.byType(QueryArtworkWidget);
      final headerWidget1 = tester.widget<QueryArtworkWidget>(
        artworkFinders.first,
      );
      expect(headerWidget1.id, 101);

      // Reorder songB to the first position
      PlaylistService.instance.reorderSong('pl-art', 1, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header artwork should now be songB (202)
      final updatedArtworkFinders = find.byType(QueryArtworkWidget);
      final headerWidget2 = tester.widget<QueryArtworkWidget>(
        updatedArtworkFinders.first,
      );
      expect(headerWidget2.id, 202);
    });
  });
}
