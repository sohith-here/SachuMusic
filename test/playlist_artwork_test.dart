import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/playlist_detail_screen.dart';
import 'package:sachu_music/screens/playlists_screen.dart';
import 'package:sachu_music/services/playlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const songNoArt1 = Song(
    id: 's-no-art-1',
    title: 'No Art Track 1',
    artist: 'Artist A',
    album: 'Album A',
    duration: Duration(minutes: 3),
    artworkId: null,
  );

  const songNoArt2 = Song(
    id: 's-no-art-2',
    title: 'No Art Track 2',
    artist: 'Artist B',
    album: 'Album B',
    duration: Duration(minutes: 4),
    artworkId: null,
  );

  const songWithArt101 = Song(
    id: 's-art-101',
    title: 'Track With Art 101',
    artist: 'Artist C',
    album: 'Album C',
    duration: Duration(minutes: 2, seconds: 30),
    artworkId: 101,
  );

  const songWithArt202 = Song(
    id: 's-art-202',
    title: 'Track With Art 202',
    artist: 'Artist D',
    album: 'Album D',
    duration: Duration(minutes: 5),
    artworkId: 202,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PlaylistService.instance.clearForTesting();
    await PlaylistService.instance.init();
  });

  group('PlaylistsScreen Cover Artwork', () {
    testWidgets('1. Empty playlist shows fallback icon', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Empty Playlist', id: 'pl-empty');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistsScreen(songs: [songWithArt101])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empty Playlist'), findsOneWidget);
      // Fallback icon inside ListTile
      expect(find.byIcon(Icons.queue_music), findsWidgets);
      // No QueryArtworkWidget rendered for the playlist item
      expect(find.byType(QueryArtworkWidget), findsNothing);
    });

    testWidgets('2. Playlist containing songs without artwork shows fallback', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist(
        'No Art Playlist',
        id: 'pl-no-art',
      );
      PlaylistService.instance.addSongsToPlaylist('pl-no-art', [
        's-no-art-1',
        's-no-art-2',
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistsScreen(songs: [songNoArt1, songNoArt2]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Art Playlist'), findsOneWidget);
      expect(find.byType(QueryArtworkWidget), findsNothing);
      expect(find.byIcon(Icons.queue_music), findsWidgets);
    });

    testWidgets(
      '3. Playlist containing a song with artwork uses artwork widget',
      (WidgetTester tester) async {
        PlaylistService.instance.createPlaylist('Art Playlist', id: 'pl-art');
        PlaylistService.instance.addSongToPlaylist('pl-art', 's-art-101');

        await tester.pumpWidget(
          const MaterialApp(home: PlaylistsScreen(songs: [songWithArt101])),
        );
        await tester.pumpAndSettle();

        expect(find.text('Art Playlist'), findsOneWidget);
        final artworkFinder = find.byType(QueryArtworkWidget);
        expect(artworkFinder, findsOneWidget);
        final widget = tester.widget<QueryArtworkWidget>(artworkFinder);
        expect(widget.id, 101);
        expect(widget.type, ArtworkType.AUDIO);
      },
    );

    testWidgets(
      '4. If first song has no artwork but later song has artwork, later artwork is selected',
      (WidgetTester tester) async {
        PlaylistService.instance.createPlaylist(
          'Mixed Playlist',
          id: 'pl-mixed',
        );
        PlaylistService.instance.addSongsToPlaylist('pl-mixed', [
          's-no-art-1',
          's-art-202',
        ]);

        await tester.pumpWidget(
          const MaterialApp(
            home: PlaylistsScreen(songs: [songNoArt1, songWithArt202]),
          ),
        );
        await tester.pumpAndSettle();

        final artworkFinder = find.byType(QueryArtworkWidget);
        expect(artworkFinder, findsOneWidget);
        final widget = tester.widget<QueryArtworkWidget>(artworkFinder);
        expect(widget.id, 202);
      },
    );

    testWidgets(
      '5. Song order is respected when selecting the first available artwork',
      (WidgetTester tester) async {
        PlaylistService.instance.createPlaylist(
          'Order Playlist',
          id: 'pl-order',
        );
        PlaylistService.instance.addSongsToPlaylist('pl-order', [
          's-art-101',
          's-art-202',
        ]);

        await tester.pumpWidget(
          const MaterialApp(
            home: PlaylistsScreen(songs: [songWithArt101, songWithArt202]),
          ),
        );
        await tester.pumpAndSettle();

        final artworkFinder = find.byType(QueryArtworkWidget);
        expect(artworkFinder, findsOneWidget);
        final widget = tester.widget<QueryArtworkWidget>(artworkFinder);
        expect(widget.id, 101);
      },
    );

    testWidgets('6. PlaylistsScreen accepts songs optionally', (
      WidgetTester tester,
    ) async {
      const screenWithSongs = PlaylistsScreen(songs: [songWithArt101]);
      expect(screenWithSongs.songs, isNotNull);

      const screenWithoutSongs = PlaylistsScreen();
      expect(screenWithoutSongs.songs, isNull);
    });

    testWidgets('7. Existing PlaylistsScreen() constructor usage works', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Legacy Call', id: 'pl-legacy');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Legacy Call'), findsOneWidget);
      expect(find.byIcon(Icons.queue_music), findsWidgets);
    });
  });

  group('PlaylistDetailScreen Cover Artwork', () {
    testWidgets('8. Empty playlist preserves empty-state behavior', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist(
        'Empty Detail',
        id: 'pl-empty-detail',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-empty-detail',
            initialSongs: [songWithArt101],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No songs in this playlist'), findsOneWidget);
      expect(find.byIcon(Icons.queue_music), findsOneWidget);
      expect(find.byType(QueryArtworkWidget), findsNothing);
    });

    testWidgets('9. Playlist Detail displays cover when artwork is available', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist(
        'Art Detail',
        id: 'pl-art-detail',
      );
      PlaylistService.instance.addSongToPlaylist('pl-art-detail', 's-art-101');

      await tester.pumpWidget(
        const MaterialApp(
          home: PlaylistDetailScreen(
            playlistId: 'pl-art-detail',
            initialSongs: [songWithArt101],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header cover (140x140) + list tile artwork (50x50) = 2 QueryArtworkWidgets
      final artworkFinders = find.byType(QueryArtworkWidget);
      expect(artworkFinders, findsNWidgets(2));

      // Check header cover size
      final headerSizedBoxFinder = find.ancestor(
        of: artworkFinders.first,
        matching: find.byType(SizedBox),
      );
      final headerSizedBox = tester.widget<SizedBox>(
        headerSizedBoxFinder.first,
      );
      expect(headerSizedBox.width, 140);
      expect(headerSizedBox.height, 140);
    });

    testWidgets(
      '10. Playlist Detail selects first available artwork even if first song has none',
      (WidgetTester tester) async {
        PlaylistService.instance.createPlaylist(
          'Mixed Detail',
          id: 'pl-mixed-detail',
        );
        PlaylistService.instance.addSongsToPlaylist('pl-mixed-detail', [
          's-no-art-1',
          's-art-202',
        ]);

        await tester.pumpWidget(
          const MaterialApp(
            home: PlaylistDetailScreen(
              playlistId: 'pl-mixed-detail',
              initialSongs: [songNoArt1, songWithArt202],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Header cover uses 202; song list has 1 QueryArtworkWidget for song 2
        final artworkFinders = find.byType(QueryArtworkWidget);
        expect(artworkFinders, findsNWidgets(2));
        final headerWidget = tester.widget<QueryArtworkWidget>(
          artworkFinders.first,
        );
        expect(headerWidget.id, 202);
      },
    );

    testWidgets(
      '11. Playlist Detail preserves existing Add Songs, Play All, and Rename controls',
      (WidgetTester tester) async {
        PlaylistService.instance.createPlaylist(
          'Controls Detail',
          id: 'pl-controls',
        );
        PlaylistService.instance.addSongToPlaylist('pl-controls', 's-art-101');

        await tester.pumpWidget(
          const MaterialApp(
            home: PlaylistDetailScreen(
              playlistId: 'pl-controls',
              initialSongs: [songWithArt101],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget); // Rename
        expect(find.byIcon(Icons.playlist_add), findsOneWidget); // Add Songs
        expect(find.byIcon(Icons.play_arrow), findsOneWidget); // Play all
        expect(find.text('Add Songs'), findsWidgets); // FAB + action tooltip
      },
    );

    testWidgets(
      '12. Artwork updates reactively when song is added or removed',
      (WidgetTester tester) async {
        PlaylistService.instance.createPlaylist('Reactive', id: 'pl-reactive');

        await tester.pumpWidget(
          const MaterialApp(home: PlaylistsScreen(songs: [songWithArt101])),
        );
        await tester.pumpAndSettle();

        // Initially empty -> no QueryArtworkWidget
        expect(find.byType(QueryArtworkWidget), findsNothing);

        // Add song with artwork
        PlaylistService.instance.addSongToPlaylist('pl-reactive', 's-art-101');
        await tester.pumpAndSettle();

        // Now has QueryArtworkWidget
        expect(find.byType(QueryArtworkWidget), findsOneWidget);

        // Remove song
        PlaylistService.instance.removeSongFromPlaylist(
          'pl-reactive',
          's-art-101',
        );
        await tester.pumpAndSettle();

        // Back to fallback
        expect(find.byType(QueryArtworkWidget), findsNothing);
      },
    );
  });
}
