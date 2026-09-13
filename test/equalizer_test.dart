import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:sachu_music/models/song.dart';
import 'package:sachu_music/screens/equalizer_bottom_sheet.dart';
import 'package:sachu_music/screens/now_playing_screen.dart';
import 'package:sachu_music/services/audio_player_service.dart';
import 'package:sachu_music/services/equalizer_service.dart';
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

  const testSong = Song(
    id: 'song-test',
    title: 'Equalizer Song',
    artist: 'Equalizer Artist',
    album: 'Equalizer Album',
    duration: Duration(minutes: 3, seconds: 30),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EqualizerService.instance.clearForTesting();
    await EqualizerService.instance.init();
    JustAudioPlatform.instance = MockJustAudioPlatform();
  });

  group('EqualizerService State & Basic Operations (1 to 13)', () {
    test('1. Default enabled=false', () {
      final service = EqualizerService.instance;
      expect(service.enabled, isFalse);
    });

    test('2. Default preset="Flat"', () {
      final service = EqualizerService.instance;
      expect(service.preset, 'Flat');
    });

    test('3. Default gains are five zeros', () {
      final service = EqualizerService.instance;
      expect(service.gains, [0.0, 0.0, 0.0, 0.0, 0.0]);
    });

    test('4. Preset selection changes preset and gains', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Bass Boost');

      expect(service.preset, 'Bass Boost');
      expect(service.gains, [5.0, 3.5, 1.0, 0.0, 0.0]);
    });

    test('5. Manual band change changes preset to Custom', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Flat');
      expect(service.preset, 'Flat');

      await service.setBandGain(0, 4.0);

      expect(service.preset, 'Custom');
      expect(service.gains[0], 4.0);
    });

    test('6. Gains are clamped to valid range', () async {
      final service = EqualizerService.instance;

      await service.setBandGain(0, 50.0);
      expect(service.gains[0], service.maxDecibels);

      await service.setBandGain(1, -50.0);
      expect(service.gains[1], service.minDecibels);
    });

    test('7. Reset restores five zero gains', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Rock');
      expect(service.gains, isNot([0.0, 0.0, 0.0, 0.0, 0.0]));

      await service.reset();

      expect(service.gains, [0.0, 0.0, 0.0, 0.0, 0.0]);
    });

    test('8. Reset sets preset to Flat', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Rock');
      expect(service.preset, 'Rock');

      await service.reset();

      expect(service.preset, 'Flat');
    });

    test('9. Reset preserves enabled state', () async {
      final service = EqualizerService.instance;
      await service.setEnabled(true);
      await service.setPreset('Bass Boost');

      await service.reset();

      expect(service.enabled, isTrue);
      expect(service.preset, 'Flat');
      expect(service.gains, [0.0, 0.0, 0.0, 0.0, 0.0]);
    });

    test('10. Persistence saves settings', () async {
      final service = EqualizerService.instance;
      await service.setEnabled(true);
      await service.setPreset('Treble Boost');
      await service.lastSaveOperation;

      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('equalizer_settings');

      expect(savedStr, isNotNull);
      expect(savedStr, contains('"enabled":true'));
      expect(savedStr, contains('"preset":"Treble Boost"'));
    });

    test('11. Persistence reload restores settings', () async {
      final service = EqualizerService.instance;
      await service.setEnabled(true);
      await service.setPreset('Vocal');
      await service.lastSaveOperation;

      service.clearForTesting();
      await service.init();

      expect(service.enabled, isTrue);
      expect(service.preset, 'Vocal');
      expect(service.gains, EqualizerService.presets['Vocal']);
    });

    test('12. Malformed persistence falls back safely', () async {
      SharedPreferences.setMockInitialValues({
        'equalizer_settings': '{invalid_json}',
      });

      final service = EqualizerService.instance;
      service.clearForTesting();
      await service.init();

      expect(service.enabled, isFalse);
      expect(service.preset, 'Flat');
      expect(service.gains, [0.0, 0.0, 0.0, 0.0, 0.0]);
    });

    test('13. Missing persistence fields fall back safely', () async {
      SharedPreferences.setMockInitialValues({
        'equalizer_settings': '{"preset":"UnknownPreset"}',
      });

      final service = EqualizerService.instance;
      service.clearForTesting();
      await service.init();

      expect(service.enabled, isFalse);
      expect(service.preset, 'Flat');
      expect(service.gains, [0.0, 0.0, 0.0, 0.0, 0.0]);
    });
  });

  group('Equalizer Preset Curves (14 to 19)', () {
    test('14. Flat produces flat gains', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Flat');
      expect(service.gains, [0.0, 0.0, 0.0, 0.0, 0.0]);
    });

    test('15. Bass Boost produces a bass-oriented curve', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Bass Boost');

      // Low bands boosted, high bands lower
      expect(service.gains[0] > service.gains[4], isTrue);
      expect(service.gains[0] > 0, isTrue);
      expect(service.gains[1] > 0, isTrue);
    });

    test('16. Treble Boost produces a treble-oriented curve', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Treble Boost');

      // High bands boosted, low bands lower
      expect(service.gains[4] > service.gains[0], isTrue);
      expect(service.gains[4] > 0, isTrue);
      expect(service.gains[3] > 0, isTrue);
    });

    test('17. Vocal produces a mid-oriented curve', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Vocal');

      // Mid band (index 2) should be highest
      expect(service.gains[2] > service.gains[0], isTrue);
      expect(service.gains[2] > service.gains[4], isTrue);
    });

    test('18. Rock produces a reasonable curve', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Rock');

      // Low and high boosted, mid scooped
      expect(service.gains[0] > service.gains[2], isTrue);
      expect(service.gains[4] > service.gains[2], isTrue);
    });

    test('19. Classical produces a reasonable curve', () async {
      final service = EqualizerService.instance;
      await service.setPreset('Classical');

      // Gentle shaping
      expect(service.gains[0] > 0, isTrue);
      expect(service.gains[4] > 0, isTrue);
    });
  });

  group('Platform Safety & Behavior (20 to 21)', () {
    test('20. Windows/non-Android path does not throw', () async {
      final service = EqualizerService.instance;
      service.setIsSupportedForTesting(false);

      expect(service.isSupported, isFalse);
      // Calling mutations on non-supported platform updates state without error
      await service.setEnabled(true);
      await service.setPreset('Bass Boost');
      await service.setBandGain(0, 3.0);
      await service.reset();
    });

    testWidgets('21. Windows displays the Android-only notice', (
      WidgetTester tester,
    ) async {
      EqualizerService.instance.setIsSupportedForTesting(false);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EqualizerBottomSheet())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Audio Equalizer is supported on Android devices only.'),
        findsOneWidget,
      );
    });
  });

  group('Equalizer Widget Tests (22 to 28)', () {
    testWidgets('22. Equalizer button exists in Now Playing', (
      WidgetTester tester,
    ) async {
      AudioPlayerService.instance.currentSong = testSong;

      await tester.pumpWidget(const MaterialApp(home: NowPlayingScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.equalizer), findsOneWidget);
      expect(find.byTooltip('Equalizer'), findsOneWidget);
    });

    testWidgets('23. Tapping Equalizer opens the bottom sheet', (
      WidgetTester tester,
    ) async {
      AudioPlayerService.instance.currentSong = testSong;

      await tester.pumpWidget(const MaterialApp(home: NowPlayingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.equalizer));
      await tester.pumpAndSettle();

      expect(find.byType(EqualizerBottomSheet), findsOneWidget);
      expect(find.text('Equalizer'), findsOneWidget);
    });

    testWidgets('24. Enable switch is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EqualizerBottomSheet())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enable Equalizer'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('25. Preset selector is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EqualizerBottomSheet())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preset'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('Flat'), findsOneWidget);
    });

    testWidgets('26. Reset button is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EqualizerBottomSheet())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('27. Five band controls render when supported', (
      WidgetTester tester,
    ) async {
      EqualizerService.instance.setIsSupportedForTesting(true);
      await EqualizerService.instance.setEnabled(true);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EqualizerBottomSheet())),
      );
      await tester.pumpAndSettle();

      // Sliders
      expect(find.byType(Slider), findsNWidgets(5));
      // Center frequency labels
      expect(find.text('60 Hz'), findsOneWidget);
      expect(find.text('230 Hz'), findsOneWidget);
      expect(find.text('910 Hz'), findsOneWidget);
      expect(find.text('3.6 kHz'), findsOneWidget);
      expect(find.text('14 kHz'), findsOneWidget);
    });

    testWidgets('28. Windows unsupported notice renders', (
      WidgetTester tester,
    ) async {
      EqualizerService.instance.setIsSupportedForTesting(false);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EqualizerBottomSheet())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Audio Equalizer is supported on Android devices only.'),
        findsOneWidget,
      );
      // Switch is disabled
      final switchWidget = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchWidget.onChanged, isNull);
    });
  });
}
