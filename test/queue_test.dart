import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/up_next_screen.dart';
import 'package:sachu_music/services/audio_player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const songA = Song(
    id: 'song-a',
    title: 'Song Alpha',
    artist: 'Artist A',
    album: 'Album A',
    duration: Duration(minutes: 3),
  );
  const songB = Song(
    id: 'song-b',
    title: 'Song Beta',
    artist: 'Artist B',
    album: 'Album B',
    duration: Duration(minutes: 4),
  );
  const songC = Song(
    id: 'song-c',
    title: 'Song Gamma',
    artist: 'Artist C',
    album: 'Album C',
    duration: Duration(minutes: 2),
  );
  const songD = Song(
    id: 'song-d',
    title: 'Song Delta',
    artist: 'Artist D',
    album: 'Album D',
    duration: Duration(minutes: 5),
  );

  final service = AudioPlayerService.instance;

  group('AudioPlayerService Queue Unit Tests', () {
    setUp(() {
      service.setQueueForTesting(
        playlist: [songA, songB, songC, songD],
        currentSong: songB,
      );
    });

    test('exposes read-only queue and current index', () {
      expect(service.queue.length, 4);
      expect(service.queue[0].id, 'song-a');
      expect(service.queue[1].id, 'song-b');
      expect(service.currentIndex, 1);

      // Queue is unmodifiable
      expect(() => (service.queue as List).add(songA), throwsUnsupportedError);
    });

    test('cannot remove currently playing song via public API', () {
      // songB is at index 1
      final removedCurrent = service.removeFromQueue(1);
      expect(removedCurrent, isFalse);
      expect(service.queue.length, 4);
      expect(service.currentSong?.id, 'song-b');
    });

    test('cannot remove songs before current index via public API', () {
      // songA is at index 0 (played prior to songB)
      final removedPast = service.removeFromQueue(0);
      expect(removedPast, isFalse);
      expect(service.queue.length, 4);
    });

    test('cannot remove out of bound indices', () {
      expect(service.removeFromQueue(-1), isFalse);
      expect(service.removeFromQueue(99), isFalse);
      expect(service.queue.length, 4);
    });

    test('successfully removes upcoming song and keeps lists synchronized', () {
      // songC is at index 2 (upcoming)
      final removed = service.removeFromQueue(2);
      expect(removed, isTrue);
      expect(service.queue.length, 3);
      expect(service.queue.map((s) => s.id).toList(), ['song-a', 'song-b', 'song-d']);
    });

    test('removal does not revive a song when shuffle is toggled', () async {
      // Start with shuffle enabled: songB first, then remaining
      service.setQueueForTesting(
        playlist: [songB, songA, songC, songD],
        currentSong: songB,
        shuffle: true,
      );

      // Remove upcoming songC (index 2)
      final removed = service.removeFromQueue(2);
      expect(removed, isTrue);
      expect(service.queue.any((s) => s.id == 'song-c'), isFalse);

      // Toggle shuffle off
      await service.toggleShuffle();

      // songC must NOT be revived!
      expect(service.isShuffleEnabled, isFalse);
      expect(service.queue.any((s) => s.id == 'song-c'), isFalse);

      // Toggle shuffle back on
      await service.toggleShuffle();
      expect(service.isShuffleEnabled, isTrue);
      expect(service.queue.any((s) => s.id == 'song-c'), isFalse);
    });

    test('queueStream emits updated list when song is removed', () async {
      service.setQueueForTesting(
        playlist: [songA, songB, songC],
        currentSong: songA,
      );

      final emissions = <List<Song>>[];
      final sub = service.queueStream.listen(emissions.add);

      await pumpEventQueue();
      service.removeFromQueue(1);
      await pumpEventQueue();

      expect(emissions.length, 2);
      expect(emissions.first.length, 3);
      expect(emissions.last.length, 2);

      await sub.cancel();
    });
  });

  group('UpNextScreen Widget Tests', () {
    testWidgets('renders empty state when queue and current song are empty',
        (WidgetTester tester) async {
      service.setQueueForTesting(playlist: [], currentSong: null);

      await tester.pumpWidget(
        const MaterialApp(
          home: UpNextScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Queue is empty'), findsOneWidget);
    });

    testWidgets('renders Now Playing and Up Next sections correctly',
        (WidgetTester tester) async {
      service.setQueueForTesting(
        playlist: [songA, songB, songC],
        currentSong: songA,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: UpNextScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Now Playing header and title
      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('Song Alpha'), findsOneWidget);

      // Up Next header and count
      expect(find.text('Up Next'), findsNWidgets(2));
      expect(find.text('2 songs'), findsOneWidget);
      expect(find.text('Song Beta'), findsOneWidget);
      expect(find.text('Song Gamma'), findsOneWidget);

      // Remove buttons exist only for upcoming songs (2 buttons)
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      // Tap remove button for the first upcoming song (Song Beta)
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // Up Next should now have 1 song (Song Gamma)
      expect(find.text('1 song'), findsOneWidget);
      expect(find.text('Song Beta'), findsNothing);
      expect(find.text('Song Gamma'), findsOneWidget);
    });

    testWidgets('gracefully handles empty Up Next when current song is last',
        (WidgetTester tester) async {
      service.setQueueForTesting(
        playlist: [songA, songB],
        currentSong: songB,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: UpNextScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('Song Beta'), findsOneWidget);
      expect(find.text('0 songs'), findsOneWidget);
      expect(find.text('No upcoming songs'), findsOneWidget);
    });
  });
}
