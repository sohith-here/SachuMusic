import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/add_songs_to_playlist_screen.dart';
import 'package:sachu_music/screens/playlist_detail_screen.dart';
import 'package:sachu_music/screens/playlists_screen.dart';
import 'package:sachu_music/services/playlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaylistService.instance.clearForTesting();
  });

  testWidgets('PlaylistsScreen renders empty state and creates playlist',
      (WidgetTester tester) async {
    await PlaylistService.instance.init();

    await tester.pumpWidget(
      const MaterialApp(
        home: PlaylistsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No playlists yet'), findsOneWidget);

    // Tap FloatingActionButton to open create dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New Playlist'), findsOneWidget);

    // Enter name
    await tester.enterText(find.byType(TextField), 'My Summer Vibes');
    await tester.tap(find.text('Create'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify playlist was created
    expect(PlaylistService.instance.playlists.length, 1);
    expect(PlaylistService.instance.playlists.first.name, 'My Summer Vibes');
    expect(find.text('My Summer Vibes'), findsWidgets);
  });

  testWidgets('PlaylistsScreen displays list and confirms deletion',
      (WidgetTester tester) async {
    await PlaylistService.instance.init();
    PlaylistService.instance.createPlaylist('Study Beats');

    await tester.pumpWidget(
      const MaterialApp(
        home: PlaylistsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Study Beats'), findsOneWidget);
    expect(find.text('0 songs'), findsOneWidget);

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Playlist'), findsOneWidget);
    expect(find.text('Are you sure you want to delete "Study Beats"?'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Study Beats'), findsNothing);
    expect(PlaylistService.instance.playlists, isEmpty);
  });

  testWidgets('AddSongsToPlaylistScreen indicates existing songs and adds selected songs',
      (WidgetTester tester) async {
    await PlaylistService.instance.init();
    PlaylistService.instance.createPlaylist('Party', id: 'pl-party');
    PlaylistService.instance.addSongToPlaylist('pl-party', 'song-1');

    const song1 = Song(
      id: 'song-1',
      title: 'First Song',
      artist: 'Artist 1',
      album: 'Album 1',
      duration: Duration(minutes: 3),
    );
    const song2 = Song(
      id: 'song-2',
      title: 'Second Song',
      artist: 'Artist 2',
      album: 'Album 2',
      duration: Duration(minutes: 4),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AddSongsToPlaylistScreen(
          playlistId: 'pl-party',
          initialSongs: [song1, song2],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Songs'), findsOneWidget);
    expect(find.text('First Song'), findsOneWidget);
    expect(find.text('Second Song'), findsOneWidget);

    // song-1 is already in playlist:
    expect(find.text('In playlist'), findsOneWidget);

    // Tap song-2 to select it
    await tester.tap(find.text('Second Song'));
    await tester.pumpAndSettle();

    expect(find.text('Add (1)'), findsOneWidget);

    // Tap the Add button in AppBar
    await tester.tap(find.text('Add (1)'));
    await tester.pumpAndSettle();

    // Verify playlist now contains song-1 and song-2
    final updated = PlaylistService.instance.getPlaylist('pl-party')!;
    expect(updated.songIds, ['song-1', 'song-2']);
  });

  testWidgets('PlaylistDetailScreen shows Add Songs action and FAB',
      (WidgetTester tester) async {
    await PlaylistService.instance.init();
    PlaylistService.instance.createPlaylist('Gym', id: 'pl-gym');

    await tester.pumpWidget(
      const MaterialApp(
        home: PlaylistDetailScreen(playlistId: 'pl-gym'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Gym'), findsOneWidget);
    // Finds Add Songs tooltip in AppBar and FAB label
    expect(find.text('Add Songs'), findsWidgets);
    expect(find.byIcon(Icons.playlist_add), findsOneWidget);
  });
}
