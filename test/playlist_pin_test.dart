import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:sachu_music/models/playlist.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/playlist_detail_screen.dart';
import 'package:sachu_music/screens/playlists_screen.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PlaylistService.instance.clearForTesting();
    await PlaylistService.instance.init();
    JustAudioPlatform.instance = MockJustAudioPlatform();
  });

  group('Playlist Model Tests (1 to 7)', () {
    test('1. Default isPinned is false', () {
      const playlist = Playlist(id: 'pl-1', name: 'My Playlist');
      expect(playlist.isPinned, isFalse);
    });

    test('2. Constructor accepts isPinned true', () {
      const playlist = Playlist(
        id: 'pl-1',
        name: 'My Playlist',
        isPinned: true,
      );
      expect(playlist.isPinned, isTrue);
    });

    test('3. copyWith(isPinned: true) works', () {
      const playlist = Playlist(id: 'pl-1', name: 'My Playlist');
      final updated = playlist.copyWith(isPinned: true);
      expect(updated.isPinned, isTrue);
    });

    test('4. copyWith preserves id/name/songIds', () {
      const playlist = Playlist(
        id: 'pl-fixed',
        name: 'Rock Classics',
        songIds: ['s1', 's2'],
      );
      final updated = playlist.copyWith(isPinned: true);

      expect(updated.id, 'pl-fixed');
      expect(updated.name, 'Rock Classics');
      expect(updated.songIds, ['s1', 's2']);
      expect(updated.isPinned, isTrue);
    });

    test('5. toMap includes isPinned', () {
      const playlist = Playlist(
        id: 'pl-1',
        name: 'Pinned Playlist',
        isPinned: true,
      );
      final map = playlist.toMap();

      expect(map['isPinned'], isTrue);
    });

    test('6. fromMap reads isPinned', () {
      final map = {
        'id': 'pl-1',
        'name': 'Pinned Playlist',
        'songIds': ['s1'],
        'isPinned': true,
      };
      final playlist = Playlist.fromMap(map);

      expect(playlist.isPinned, isTrue);
    });

    test('7. fromMap defaults missing isPinned to false', () {
      final map = {
        'id': 'pl-legacy',
        'name': 'Legacy Playlist',
        'songIds': ['s1'],
      };
      final playlist = Playlist.fromMap(map);

      expect(playlist.isPinned, isFalse);
    });
  });

  group('PlaylistService Tests (8 to 19)', () {
    test('8. Pin unpinned playlist', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Test PL', id: 'pl-1');

      expect(service.getPlaylist('pl-1')?.isPinned, isFalse);
      final success = service.togglePinPlaylist('pl-1');

      expect(success, isTrue);
      expect(service.getPlaylist('pl-1')?.isPinned, isTrue);
    });

    test('9. Unpin pinned playlist', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Test PL', id: 'pl-1');
      service.togglePinPlaylist('pl-1');
      expect(service.getPlaylist('pl-1')?.isPinned, isTrue);

      final success = service.togglePinPlaylist('pl-1');
      expect(success, isTrue);
      expect(service.getPlaylist('pl-1')?.isPinned, isFalse);
    });

    test('10. Nonexistent playlist returns false', () {
      final service = PlaylistService.instance;
      final success = service.togglePinPlaylist('nonexistent-id');

      expect(success, isFalse);
    });

    test('11. Successful toggle increments changes exactly once', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Test PL', id: 'pl-1');

      final changesBefore = service.changes.value;
      service.togglePinPlaylist('pl-1');

      expect(service.changes.value, changesBefore + 1);
    });

    test('12. Failed toggle does not increment changes', () {
      final service = PlaylistService.instance;
      final changesBefore = service.changes.value;

      service.togglePinPlaylist('nonexistent-id');
      expect(service.changes.value, changesBefore);
    });

    test('13. Pin state persists across SharedPreferences reload', () async {
      final service = PlaylistService.instance;
      service.createPlaylist('Persisted Pin', id: 'pl-pin');
      service.togglePinPlaylist('pl-pin');
      await service.lastSaveOperation;

      service.clearForTesting();
      await service.init();

      final reloaded = service.getPlaylist('pl-pin');
      expect(reloaded, isNotNull);
      expect(reloaded!.isPinned, isTrue);
    });

    test('14. Legacy playlist JSON without isPinned loads as false', () async {
      const legacyJson =
          '{"id":"pl-old","name":"Old Format","songIds":["s1","s2"]}';
      SharedPreferences.setMockInitialValues({
        'saved_playlists': [legacyJson],
      });

      final service = PlaylistService.instance;
      service.clearForTesting();
      await service.init();

      final loaded = service.getPlaylist('pl-old');
      expect(loaded, isNotNull);
      expect(loaded!.isPinned, isFalse);
    });

    test('15. Rename preserves isPinned', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Original', id: 'pl-1');
      service.togglePinPlaylist('pl-1');

      service.renamePlaylist('pl-1', 'Renamed PL');

      final pl = service.getPlaylist('pl-1');
      expect(pl?.name, 'Renamed PL');
      expect(pl?.isPinned, isTrue);
    });

    test('16. Add song preserves isPinned', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Songs PL', id: 'pl-1');
      service.togglePinPlaylist('pl-1');

      service.addSongToPlaylist('pl-1', 'song-1');

      final pl = service.getPlaylist('pl-1');
      expect(pl?.songIds, ['song-1']);
      expect(pl?.isPinned, isTrue);
    });

    test('17. Remove song preserves isPinned', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Songs PL', id: 'pl-1');
      service.addSongToPlaylist('pl-1', 'song-1');
      service.togglePinPlaylist('pl-1');

      service.removeSongFromPlaylist('pl-1', 'song-1');

      final pl = service.getPlaylist('pl-1');
      expect(pl?.songIds, isEmpty);
      expect(pl?.isPinned, isTrue);
    });

    test('18. Reorder song preserves isPinned', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Reorder PL', id: 'pl-1');
      service.addSongsToPlaylist('pl-1', ['s1', 's2', 's3']);
      service.togglePinPlaylist('pl-1');

      service.reorderSong('pl-1', 0, 2);

      final pl = service.getPlaylist('pl-1');
      expect(pl?.songIds, ['s2', 's3', 's1']);
      expect(pl?.isPinned, isTrue);
    });

    test('19. Delete pinned playlist removes it normally', () {
      final service = PlaylistService.instance;
      service.createPlaylist('To Delete', id: 'pl-del');
      service.togglePinPlaylist('pl-del');

      final deleted = service.deletePlaylist('pl-del');
      expect(deleted, isTrue);
      expect(service.getPlaylist('pl-del'), isNull);
    });
  });

  group('Ordering Tests (20 to 24)', () {
    test('20. Pinned playlists appear before unpinned playlists', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Alpha', id: 'a');
      service.createPlaylist('Beta', id: 'b');
      service.togglePinPlaylist('b');

      final displayOrder = [
        ...service.playlists.where((p) => p.isPinned),
        ...service.playlists.where((p) => !p.isPinned),
      ];

      expect(displayOrder.map((p) => p.id).toList(), ['b', 'a']);
    });

    test('21. Multiple pinned playlists preserve relative order', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Alpha', id: 'a');
      service.createPlaylist('Beta', id: 'b');
      service.createPlaylist('Gamma', id: 'c');
      service.createPlaylist('Delta', id: 'd');

      // Pin b, then pin d
      service.togglePinPlaylist('b');
      service.togglePinPlaylist('d');

      final displayOrder = [
        ...service.playlists.where((p) => p.isPinned),
        ...service.playlists.where((p) => !p.isPinned),
      ];

      expect(displayOrder.map((p) => p.id).toList(), ['b', 'd', 'a', 'c']);
    });

    test('22. Multiple unpinned playlists preserve relative order', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Alpha', id: 'a');
      service.createPlaylist('Beta', id: 'b');
      service.createPlaylist('Gamma', id: 'c');
      service.createPlaylist('Delta', id: 'd');

      // Pin b
      service.togglePinPlaylist('b');

      final displayOrder = [
        ...service.playlists.where((p) => p.isPinned),
        ...service.playlists.where((p) => !p.isPinned),
      ];

      // Unpinned: a, c, d
      expect(displayOrder.map((p) => p.id).toList(), ['b', 'a', 'c', 'd']);
    });

    test('23. Pinning a playlist does not change the underlying service list order', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Alpha', id: 'a');
      service.createPlaylist('Beta', id: 'b');
      service.createPlaylist('Gamma', id: 'c');

      service.togglePinPlaylist('b');

      expect(service.playlists.map((p) => p.id).toList(), ['a', 'b', 'c']);
    });

    test('24. Unpinning restores its position among unpinned playlists', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Alpha', id: 'a');
      service.createPlaylist('Beta', id: 'b');
      service.createPlaylist('Gamma', id: 'c');

      // Pin b
      service.togglePinPlaylist('b');

      // Unpin b
      service.togglePinPlaylist('b');

      final displayOrder = [
        ...service.playlists.where((p) => p.isPinned),
        ...service.playlists.where((p) => !p.isPinned),
      ];

      expect(displayOrder.map((p) => p.id).toList(), ['a', 'b', 'c']);
    });
  });

  group('Widget Tests (25 to 32)', () {
    testWidgets('25. Unpinned playlist shows Icons.push_pin_outlined', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('My PL', id: 'pl-1');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [])),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });

    testWidgets('26. Pinned playlist shows Icons.push_pin', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('My PL', id: 'pl-1');
      PlaylistService.instance.togglePinPlaylist('pl-1');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [])),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    });

    testWidgets('27. Correct tooltip appears', (WidgetTester tester) async {
      PlaylistService.instance.createPlaylist('Unpinned PL', id: 'pl-1');
      PlaylistService.instance.createPlaylist('Pinned PL', id: 'pl-2');
      PlaylistService.instance.togglePinPlaylist('pl-2');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [])),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Pin playlist'), findsOneWidget);
      expect(find.byTooltip('Unpin playlist'), findsOneWidget);
    });

    testWidgets('28. Tapping pin moves playlist into pinned section', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Alpha', id: 'pl-a');
      PlaylistService.instance.createPlaylist('Beta', id: 'pl-b');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [])),
      );
      await tester.pumpAndSettle();

      // Initially Alpha is first, Beta is second
      var tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((tiles[0].title as Text).data, 'Alpha');
      expect((tiles[1].title as Text).data, 'Beta');

      // Tap pin on Beta (second pin button)
      final pinButtons = find.byTooltip('Pin playlist');
      await tester.tap(pinButtons.last);
      await tester.pumpAndSettle();

      // Now Beta is first (pinned), Alpha is second (unpinned)
      tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((tiles[0].title as Text).data, 'Beta');
      expect((tiles[1].title as Text).data, 'Alpha');
    });

    testWidgets('29. Tapping unpin returns playlist to unpinned ordering', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Alpha', id: 'pl-a');
      PlaylistService.instance.createPlaylist('Beta', id: 'pl-b');
      PlaylistService.instance.togglePinPlaylist('pl-b');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [])),
      );
      await tester.pumpAndSettle();

      // Beta is first because it is pinned
      var tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((tiles[0].title as Text).data, 'Beta');
      expect((tiles[1].title as Text).data, 'Alpha');

      // Tap unpin button on Beta
      await tester.tap(find.byTooltip('Unpin playlist'));
      await tester.pumpAndSettle();

      // Now Alpha is first, Beta is second (natural unpinned order)
      tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((tiles[0].title as Text).data, 'Alpha');
      expect((tiles[1].title as Text).data, 'Beta');
    });

    testWidgets('30. Rename still works', (WidgetTester tester) async {
      PlaylistService.instance.createPlaylist('Alpha', id: 'pl-a');
      PlaylistService.instance.togglePinPlaylist('pl-a');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [])),
      );
      await tester.pumpAndSettle();

      // Tap Rename button
      await tester.tap(find.byTooltip('Rename playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Playlist'), findsOneWidget);

      // Enter new name and save
      await tester.enterText(find.byType(TextField), 'Alpha Renamed');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Alpha Renamed'), findsOneWidget);
      expect(PlaylistService.instance.getPlaylist('pl-a')?.isPinned, isTrue);
    });

    testWidgets('31. Delete still works', (WidgetTester tester) async {
      PlaylistService.instance.createPlaylist('To Delete', id: 'pl-del');
      PlaylistService.instance.togglePinPlaylist('pl-del');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [])),
      );
      await tester.pumpAndSettle();

      // Tap Delete button
      await tester.tap(find.byTooltip('Delete playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Playlist'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('To Delete'), findsNothing);
      expect(PlaylistService.instance.playlists, isEmpty);
      expect(find.text('No playlists yet'), findsOneWidget);
    });

    testWidgets('32. Pinned playlist still opens PlaylistDetailScreen', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Detail Target', id: 'pl-target');
      PlaylistService.instance.togglePinPlaylist('pl-target');

      const testSong = Song(
        id: 's1',
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(minutes: 3),
      );

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [testSong])),
      );
      await tester.pumpAndSettle();

      // Tap the playlist tile
      await tester.tap(find.text('Detail Target'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies PlaylistDetailScreen is rendered
      expect(find.byType(PlaylistDetailScreen), findsOneWidget);
      expect(find.text('Detail Target'), findsWidgets);
    });
  });
}
