import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sachu_music/screens/playlist_detail_screen.dart';
import 'package:sachu_music/screens/playlists_screen.dart';
import 'package:sachu_music/services/playlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PlaylistService.instance.clearForTesting();
    await PlaylistService.instance.init();
  });

  group('PlaylistService Rename (1 to 12)', () {
    test('1. Rename succeeds', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Old Name', id: 'pl-1');

      final result = service.renamePlaylist('pl-1', 'New Name');

      expect(result, isTrue);
      expect(service.getPlaylist('pl-1')?.name, 'New Name');
    });

    test('2. Leading/trailing whitespace is trimmed', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Old', id: 'pl-1');

      final result = service.renamePlaylist('pl-1', '   Trimmed Name   ');

      expect(result, isTrue);
      expect(service.getPlaylist('pl-1')?.name, 'Trimmed Name');
    });

    test('3. Empty string is rejected', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Original', id: 'pl-1');

      final result = service.renamePlaylist('pl-1', '');

      expect(result, isFalse);
      expect(service.getPlaylist('pl-1')?.name, 'Original');
    });

    test('4. Whitespace-only string is rejected', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Original', id: 'pl-1');

      final result = service.renamePlaylist('pl-1', '    ');

      expect(result, isFalse);
      expect(service.getPlaylist('pl-1')?.name, 'Original');
    });

    test('5. Existing name remains unchanged after invalid rename', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Original Name', id: 'pl-1');

      service.renamePlaylist('pl-1', '');
      service.renamePlaylist('pl-1', '   ');
      service.renamePlaylist('pl-1', '\t\n');

      expect(service.getPlaylist('pl-1')?.name, 'Original Name');
    });

    test('6. Non-existent playlist ID returns false without throwing', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Existing', id: 'pl-1');

      final result = service.renamePlaylist('non-existent-id', 'Something');

      expect(result, isFalse);
      expect(service.playlists.length, 1);
      expect(service.playlists.first.name, 'Existing');
    });

    test('7. Playlist ID remains exactly unchanged', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Old', id: 'pl-fixed-id');

      service.renamePlaylist('pl-fixed-id', 'New Name');

      final pl = service.getPlaylist('pl-fixed-id');
      expect(pl, isNotNull);
      expect(pl!.id, 'pl-fixed-id');
    });

    test(
      '8. Playlist songIds remain exactly unchanged and in the same order',
      () {
        final service = PlaylistService.instance;
        service.createPlaylist('Party', id: 'pl-1');
        service.addSongsToPlaylist('pl-1', ['song-x', 'song-y', 'song-z']);

        service.renamePlaylist('pl-1', 'Super Party');

        final pl = service.getPlaylist('pl-1');
        expect(pl, isNotNull);
        expect(pl!.songIds, ['song-x', 'song-y', 'song-z']);
      },
    );

    test('9. Playlist ordering remains unchanged', () {
      final service = PlaylistService.instance;
      service.createPlaylist('A', id: 'pl-a');
      service.createPlaylist('B', id: 'pl-b');
      service.createPlaylist('C', id: 'pl-c');

      service.renamePlaylist('pl-b', 'B Renamed');

      expect(service.playlists.map((p) => p.id).toList(), [
        'pl-a',
        'pl-b',
        'pl-c',
      ]);
      expect(service.playlists[0].name, 'A');
      expect(service.playlists[1].name, 'B Renamed');
      expect(service.playlists[2].name, 'C');
    });

    test('10. PlaylistService.changes updates after a successful rename', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Old', id: 'pl-1');

      final initialChanges = service.changes.value;
      service.renamePlaylist('pl-1', 'New');

      expect(service.changes.value, initialChanges + 1);
    });

    test('11. Renamed playlist persists through the existing SharedPreferences persistence/reload mechanism', () async {
      final service = PlaylistService.instance;
      service.createPlaylist('Old', id: 'pl-1');
      service.addSongToPlaylist('pl-1', 'song-1');

      service.renamePlaylist('pl-1', 'Persisted Name');
      await service.lastSaveOperation;

      service.clearForTesting();
      await service.init();

      final loaded = service.getPlaylist('pl-1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Persisted Name');
      expect(loaded.songIds, ['song-1']);
    });

    test('12. Renaming to the same trimmed name does not unnecessarily mutate/persist', () {
      final service = PlaylistService.instance;
      service.createPlaylist('Exact Name', id: 'pl-1');

      final changesBefore = service.changes.value;
      final result = service.renamePlaylist('pl-1', '  Exact Name  ');

      expect(result, isTrue);
      expect(service.changes.value, changesBefore);
    });
  });

  group('PlaylistsScreen Rename (13 to 20)', () {
    testWidgets('13. Rename icon appears', (WidgetTester tester) async {
      PlaylistService.instance.createPlaylist('Study Beats', id: 'pl-1');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('14. Tapping Rename opens the dialog', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Study Beats', id: 'pl-1');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Rename Playlist'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('15. Dialog contains the current playlist name', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Study Beats', id: 'pl-1');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Study Beats');
    });

    testWidgets('16. Cancel leaves the original name unchanged', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Study Beats', id: 'pl-1');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Changed Name');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Playlist'), findsNothing);
      expect(PlaylistService.instance.getPlaylist('pl-1')?.name, 'Study Beats');
      expect(find.text('Study Beats'), findsOneWidget);
    });

    testWidgets('17. Saving a valid new name updates the displayed playlist', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Study Beats', id: 'pl-1');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Lofi Chill  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Playlist'), findsNothing);
      expect(find.text('Lofi Chill'), findsOneWidget);
      expect(PlaylistService.instance.getPlaylist('pl-1')?.name, 'Lofi Chill');
    });

    testWidgets('18. Blank name does not rename the playlist', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Lofi Chill', id: 'pl-1');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Dialog stays open
      expect(find.text('Rename Playlist'), findsOneWidget);
      expect(PlaylistService.instance.getPlaylist('pl-1')?.name, 'Lofi Chill');

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('19. Whitespace-only name does not rename the playlist', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Lofi Chill', id: 'pl-1');

      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '    ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Dialog stays open
      expect(find.text('Rename Playlist'), findsOneWidget);
      expect(PlaylistService.instance.getPlaylist('pl-1')?.name, 'Lofi Chill');

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      '20. Existing delete button remains directly accessible and functional',
      (WidgetTester tester) async {
        PlaylistService.instance.createPlaylist('Study Beats', id: 'pl-1');

        await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        expect(find.text('Delete Playlist'), findsOneWidget);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(PlaylistService.instance.playlists, isEmpty);
        expect(find.text('No playlists yet'), findsOneWidget);
      },
    );
  });

  group('PlaylistDetailScreen Rename (21 to 24)', () {
    testWidgets('21. Rename action appears in the AppBar', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Gym Workout', id: 'pl-gym');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistDetailScreen(playlistId: 'pl-gym')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.widgetWithIcon(IconButton, Icons.edit_outlined),
        findsOneWidget,
      );
    });

    testWidgets('22. Tapping it opens the rename dialog', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Gym Workout', id: 'pl-gym');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistDetailScreen(playlistId: 'pl-gym')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rename Playlist'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Gym Workout');
    });

    testWidgets('23. Saving a new name immediately updates the AppBar title', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Gym Workout', id: 'pl-gym');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistDetailScreen(playlistId: 'pl-gym')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'Intense Cardio');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rename Playlist'), findsNothing);
      expect(find.text('Intense Cardio'), findsOneWidget);
      expect(
        PlaylistService.instance.getPlaylist('pl-gym')?.name,
        'Intense Cardio',
      );
    });

    testWidgets('24. Cancel leaves the original name unchanged', (
      WidgetTester tester,
    ) async {
      PlaylistService.instance.createPlaylist('Intense Cardio', id: 'pl-gym');

      await tester.pumpWidget(
        const MaterialApp(home: PlaylistDetailScreen(playlistId: 'pl-gym')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'Should Not Save');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rename Playlist'), findsNothing);
      expect(find.text('Intense Cardio'), findsOneWidget);
      expect(
        PlaylistService.instance.getPlaylist('pl-gym')?.name,
        'Intense Cardio',
      );
    });
  });
}
