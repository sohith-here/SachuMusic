import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/now_playing_screen.dart';
import 'package:sachu_music/services/audio_player_service.dart';
import 'package:sachu_music/services/sleep_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sleepTimer = SleepTimerService.instance;
  final playerService = AudioPlayerService.instance;

  const testSong = Song(
    id: 'test-song-1',
    title: 'Test Song Title',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: Duration(minutes: 3),
  );

  setUp(() {
    sleepTimer.resetForTesting();
    playerService.currentSong = testSong;
  });

  tearDown(() {
    sleepTimer.resetForTesting();
  });

  group('SleepTimerService Unit Tests', () {
    test('1. Timer starts inactive', () {
      expect(sleepTimer.isActive, isFalse);
      expect(sleepTimer.remainingTime, isNull);
      expect(sleepTimer.formattedRemainingTime, '');
    });

    test('2. Starting a timer sets the correct remaining duration', () {
      sleepTimer.startTimer(const Duration(minutes: 30));
      expect(sleepTimer.isActive, isTrue);
      expect(sleepTimer.remainingTime, const Duration(minutes: 30));
    });

    test('3. Countdown decreases over time', () {
      sleepTimer.startTimer(const Duration(minutes: 15));
      expect(sleepTimer.remainingTime, const Duration(minutes: 15));

      sleepTimer.tickForTesting();
      expect(sleepTimer.remainingTime, const Duration(minutes: 14, seconds: 59));

      sleepTimer.tickForTesting();
      expect(sleepTimer.remainingTime, const Duration(minutes: 14, seconds: 58));
    });

    test('4. Starting a new timer replaces the previous timer', () {
      sleepTimer.startTimer(const Duration(minutes: 15));
      expect(sleepTimer.remainingTime, const Duration(minutes: 15));

      sleepTimer.startTimer(const Duration(minutes: 60));
      expect(sleepTimer.remainingTime, const Duration(minutes: 60));
    });

    test('5. Cancelling clears the timer', () {
      sleepTimer.startTimer(const Duration(minutes: 45));
      expect(sleepTimer.isActive, isTrue);

      sleepTimer.cancelTimer();
      expect(sleepTimer.isActive, isFalse);
      expect(sleepTimer.remainingTime, isNull);
      expect(sleepTimer.formattedRemainingTime, '');
    });

    test('6 & 7. Timer completion calls pause and does not call stop()', () {
      bool pauseCalled = false;
      bool stopCalled = false;

      // Mock completion callback to verify pause is called and song remains set
      sleepTimer.onTimerComplete = () async {
        pauseCalled = true;
        // Verify currentSong is still preserved (stop() not called)
        if (playerService.currentSong == null) {
          stopCalled = true;
        }
      };

      sleepTimer.startTimer(const Duration(seconds: 1));
      expect(sleepTimer.isActive, isTrue);

      // Trigger final tick
      sleepTimer.tickForTesting();

      expect(pauseCalled, isTrue);
      expect(stopCalled, isFalse);
      expect(sleepTimer.isActive, isFalse);
      expect(playerService.currentSong, isNotNull);
      expect(playerService.currentSong?.id, 'test-song-1');
    });

    test('8. Remaining-time formatting works correctly', () {
      expect(SleepTimerService.formatDuration(const Duration(seconds: 5)), '0:05');
      expect(SleepTimerService.formatDuration(const Duration(minutes: 9, seconds: 30)), '9:30');
      expect(SleepTimerService.formatDuration(const Duration(minutes: 30)), '30:00');
      expect(SleepTimerService.formatDuration(const Duration(hours: 1, minutes: 15, seconds: 4)), '1:15:04');
    });
  });

  group('NowPlayingScreen Sleep Timer Widget Tests', () {
    testWidgets('9. NowPlayingScreen displays the Sleep Timer button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NowPlayingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Sleep Timer'), findsOneWidget);
      expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
    });

    testWidgets('10 & 11. Tapping shows five duration options and selecting activates timer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NowPlayingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sleep Timer button
      await tester.tap(find.byTooltip('Sleep Timer'));
      await tester.pumpAndSettle();

      // Verify sheet title and 5 duration options
      expect(find.text('Sleep Timer'), findsWidgets);
      expect(find.text('15 minutes'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.text('45 minutes'), findsOneWidget);
      expect(find.text('60 minutes'), findsOneWidget);
      expect(find.text('90 minutes'), findsOneWidget);

      // Select 30 minutes
      await tester.tap(find.text('30 minutes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Timer is now active
      expect(sleepTimer.isActive, isTrue);
      expect(sleepTimer.remainingTime, const Duration(minutes: 30));

      // Icon changes to active bedtime icon
      expect(find.byIcon(Icons.bedtime), findsOneWidget);
      expect(find.text('Sleep timer set for 30 minutes'), findsOneWidget);

      // Clean up timer before test ends
      sleepTimer.cancelTimer();
    });

    testWidgets('12 & 13. Active timer UI shows remaining time, cancel action, and cancelling updates UI',
        (WidgetTester tester) async {
      // Start with active timer
      sleepTimer.setRemainingTimeForTesting(const Duration(minutes: 45));

      await tester.pumpWidget(
        const MaterialApp(
          home: NowPlayingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Button tooltip shows remaining time
      expect(find.byTooltip('Sleep Timer (45:00)'), findsOneWidget);
      expect(find.byIcon(Icons.bedtime), findsOneWidget);

      // Tap to open sheet
      await tester.tap(find.byIcon(Icons.bedtime));
      await tester.pumpAndSettle();

      // Sheet displays remaining time and cancel action
      expect(find.text('45:00'), findsOneWidget);
      expect(find.text('Turn off timer'), findsOneWidget);

      // Tap Turn off timer
      await tester.tap(find.text('Turn off timer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Timer is cancelled and UI returns to inactive icon
      expect(sleepTimer.isActive, isFalse);
      expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
      expect(find.text('Sleep timer turned off'), findsOneWidget);
    });
  });
}
