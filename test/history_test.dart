import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:sachu_music/models/playback_history_item.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/history_screen.dart';
import 'package:sachu_music/services/audio_player_service.dart';
import 'package:sachu_music/services/playback_history_service.dart';
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
    artist: 'Artist Alpha',
    album: 'Album Alpha',
    path: '/music/song_a.mp3',
    duration: Duration(minutes: 3, seconds: 30),
    artworkId: 101,
  );

  const songB = Song(
    id: 'song-b',
    title: 'Song Beta',
    artist: 'Artist Beta',
    album: 'Album Beta',
    path: '/music/song_b.mp3',
    duration: Duration(minutes: 4, seconds: 15),
    artworkId: 102,
  );

  const songC = Song(
    id: 'song-c',
    title: 'Song Gamma',
    artist: 'Artist Gamma',
    album: 'Album Gamma',
    path: '/music/song_c.mp3',
    duration: Duration(minutes: 2, seconds: 45),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaybackHistoryService.instance.clearForTesting();
  });

  group('1. PlaybackHistoryItem Serialization', () {
    test('Song fields and playedAt survive toMap and fromMap', () {
      final playedAt = DateTime(2026, 9, 13, 14, 30, 0);
      final item = PlaybackHistoryItem(
        id: 'hist-1',
        song: songA,
        playedAt: playedAt,
      );

      final map = item.toMap();
      final restored = PlaybackHistoryItem.fromMap(map);

      expect(restored.id, 'hist-1');
      expect(restored.playedAt, playedAt);
      expect(restored.song.id, songA.id);
      expect(restored.song.title, songA.title);
      expect(restored.song.artist, songA.artist);
      expect(restored.song.album, songA.album);
      expect(restored.song.path, songA.path);
      expect(restored.song.duration, songA.duration);
      expect(restored.song.artworkId, songA.artworkId);
    });

    test('fromMap handles missing or corrupted map safely', () {
      final restored = PlaybackHistoryItem.fromMap({});
      expect(restored.id, '');
      expect(restored.song.id, '');
      expect(restored.song.title, '');
      expect(restored.playedAt, isNotNull);
    });
  });

  group('2 & 3. Recording and Ordering', () {
    test('Recording Song A, Song B, and Song A again creates 3 distinct entries with newest first', () async {
      final service = PlaybackHistoryService.instance;
      await service.init();

      final t1 = DateTime(2026, 9, 13, 10, 0, 0);
      final t2 = DateTime(2026, 9, 13, 10, 5, 0);
      final t3 = DateTime(2026, 9, 13, 10, 10, 0);

      service.recordPlayback(songA, timestamp: t1);
      service.recordPlayback(songB, timestamp: t2);
      service.recordPlayback(songA, timestamp: t3);

      expect(service.count, 3);
      expect(service.isEmpty, isFalse);

      final history = service.history;
      // Newest first:
      expect(history[0].song.id, 'song-a');
      expect(history[0].playedAt, t3);

      expect(history[1].song.id, 'song-b');
      expect(history[1].playedAt, t2);

      // Older Song A remains in history (no deduplication)
      expect(history[2].song.id, 'song-a');
      expect(history[2].playedAt, t1);
    });
  });

  group('4. 100-Entry Limit', () {
    test('Adding more than 100 entries enforces 100 max, retaining newest and dropping oldest', () async {
      final service = PlaybackHistoryService.instance;
      await service.init();

      for (int i = 0; i < 110; i++) {
        final song = Song(
          id: 'song-$i',
          title: 'Song $i',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
        );
        service.recordPlayback(
          song,
          timestamp: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        );
      }

      expect(service.count, 100);
      expect(service.history.length, 100);

      // Newest entry (index 109) is at position 0
      expect(service.history.first.song.id, 'song-109');

      // Oldest retained is song-10 (items 0 to 9 were dropped)
      expect(service.history.last.song.id, 'song-10');
    });
  });

  group('5. Persistence', () {
    test(
      'Saved history persists to SharedPreferences and reloads correctly',
      () async {
        final service = PlaybackHistoryService.instance;
        await service.init();

        final t1 = DateTime(2026, 9, 13, 8, 0, 0);
        final t2 = DateTime(2026, 9, 13, 9, 0, 0);

        service.recordPlayback(songA, timestamp: t1);
        service.recordPlayback(songB, timestamp: t2);
        await service.lastSaveOperation;

        // Verify SharedPreferences has the saved items
        final prefs = await SharedPreferences.getInstance();
        final savedList = prefs.getStringList('playback_history');
        expect(savedList, isNotNull);
        expect(savedList!.length, 2);

        // Simulate app restart
        service.clearForTesting();
        expect(service.count, 0);

        await service.init();
        expect(service.count, 2);
        expect(service.history[0].song.id, 'song-b');
        expect(service.history[1].song.id, 'song-a');
      },
    );
  });

  group('6. Clear History', () {
    test('clearHistory() empties memory and persisted storage', () async {
      final service = PlaybackHistoryService.instance;
      await service.init();

      service.recordPlayback(songA);
      service.recordPlayback(songB);
      await service.lastSaveOperation;
      expect(service.count, 2);

      await service.clearHistory();

      expect(service.count, 0);
      expect(service.isEmpty, isTrue);
      expect(service.history, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList('playback_history');
      expect(savedList, isEmpty);
    });
  });

  group('7. Corrupt Data Handling', () {
    test('Skips malformed JSON entries safely during load', () async {
      final validItemJson = jsonEncode(
        PlaybackHistoryItem(
          id: 'valid-1',
          song: songA,
          playedAt: DateTime(2026, 9, 13, 12, 0, 0),
        ).toMap(),
      );

      SharedPreferences.setMockInitialValues({
        'playback_history': [
          'this is not valid json',
          validItemJson,
          '{"corrupted": true}',
        ],
      });

      final service = PlaybackHistoryService.instance;
      await service.init();

      expect(service.count, 1);
      expect(service.history.first.song.id, 'song-a');
    });
  });

  group('Timestamp Formatter', () {
    test('formatPlayedAt produces human-friendly deterministic labels', () {
      final baseNow = DateTime(2026, 9, 13, 14, 0, 0);

      // < 1 minute -> Just now
      expect(
        formatPlayedAt(
          baseNow.subtract(const Duration(seconds: 30)),
          now: baseNow,
        ),
        'Just now',
      );

      // 5 minutes ago
      expect(
        formatPlayedAt(
          baseNow.subtract(const Duration(minutes: 5)),
          now: baseNow,
        ),
        '5m ago',
      );

      // 2 hours ago (same day)
      expect(
        formatPlayedAt(
          baseNow.subtract(const Duration(hours: 2)),
          now: baseNow,
        ),
        '2h ago',
      );

      // Yesterday
      final yesterday = DateTime(2026, 9, 12, 14, 0, 0);
      expect(formatPlayedAt(yesterday, now: baseNow), 'Yesterday');

      // 3 days ago
      final threeDaysAgo = DateTime(2026, 9, 10, 14, 0, 0);
      expect(formatPlayedAt(threeDaysAgo, now: baseNow), '3d ago');

      // Older date (same year)
      final augDate = DateTime(2026, 8, 15, 14, 0, 0);
      expect(formatPlayedAt(augDate, now: baseNow), 'Aug 15');

      // Previous year
      final lastYear = DateTime(2025, 12, 25, 14, 0, 0);
      expect(formatPlayedAt(lastYear, now: baseNow), 'Dec 25, 2025');
    });
  });

  group('8. History UI Widget Tests', () {
    testWidgets('Renders empty state when history is empty', (
      WidgetTester tester,
    ) async {
      await PlaybackHistoryService.instance.init();

      await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      expect(find.text('No listening history yet'), findsOneWidget);
    });

    testWidgets('Renders history entries and handles clear confirmation', (
      WidgetTester tester,
    ) async {
      final service = PlaybackHistoryService.instance;
      await service.init();
      service.recordPlayback(songA);
      service.recordPlayback(songB);

      await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Song Beta'), findsOneWidget);
      expect(find.text('Song Alpha'), findsOneWidget);
      expect(find.text('No listening history yet'), findsNothing);

      // Tap clear history button in AppBar
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Clear Listening History'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to clear your listening history? This action cannot be undone.',
        ),
        findsOneWidget,
      );

      // Tap Cancel first
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Entries should still exist
      expect(service.count, 2);
      expect(find.text('Song Beta'), findsOneWidget);

      // Tap clear again and confirm
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Entries should be removed and empty state shown
      expect(service.count, 0);
      expect(find.text('No listening history yet'), findsOneWidget);
    });
  });

  group('9. AudioPlayerService Playback Recording Tests', () {
    setUp(() {
      JustAudioPlatform.instance = MockJustAudioPlatform();
      PlaybackHistoryService.instance.clearForTesting();
    });

    test('Verify next/queue transitions record exactly once and do not duplicate entries', () async {
      final playerService = AudioPlayerService.instance;
      final historyService = PlaybackHistoryService.instance;
      await historyService.init();

      playerService.setQueueForTesting(
        playlist: [songA, songB, songC],
        currentSong: songA,
      );

      expect(historyService.count, 0);

      // 1. Next playback transition
      await playerService.next();
      expect(playerService.currentSong?.id, songB.id);
      expect(historyService.count, 1);
      expect(historyService.history.first.song.id, songB.id);

      // 2. Another Next playback transition
      await playerService.next();
      expect(playerService.currentSong?.id, songC.id);
      expect(historyService.count, 2);
      expect(historyService.history[0].song.id, songC.id);
      expect(historyService.history[1].song.id, songB.id);

      // 3. Previous playback transition
      await playerService.previous();
      expect(playerService.currentSong?.id, songB.id);
      expect(historyService.count, 3);
      expect(historyService.history[0].song.id, songB.id);

      // 4. Queue selection
      await playerService.playFromQueue(0);
      expect(playerService.currentSong?.id, songA.id);
      expect(historyService.count, 4);
      expect(historyService.history[0].song.id, songA.id);
    });
  });
}
