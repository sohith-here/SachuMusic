import 'dart:async';
import 'dart:math';

import 'package:just_audio/just_audio.dart';

import 'recently_played_service.dart';
import '../models/song.dart';

class AudioPlayerService {
  AudioPlayerService._() {
    _processingSubscription = player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleSongCompleted();
      }
    });
  }

  static final AudioPlayerService instance = AudioPlayerService._();

  final AudioPlayer player = AudioPlayer();
  final RecentlyPlayedService _recentlyPlayed = RecentlyPlayedService.instance;

  List<Song> _playlist = [];
  List<Song> _originalPlaylist = [];
  List<Song> _shufflePlaylist = [];

  Song? _currentSong;

  Song? get currentSong => _currentSong;

  set currentSong(Song? song) {
    _currentSong = song;
    _currentSongController.add(song);
  }

  final StreamController<Song?> _currentSongController =
      StreamController<Song?>.broadcast();
  bool _shuffleEnabled = false;
  LoopMode _repeatMode = LoopMode.off;

  StreamSubscription<ProcessingState>? _processingSubscription;

  // ============================================================
  // CURRENT SONG
  // ============================================================

  Stream<Song?> get currentSongStream async* {
    yield currentSong;
    yield* _currentSongController.stream;
  }

  // ============================================================
  // PLAYBACK STREAMS
  // ============================================================

  Stream<Duration> get positionStream => player.positionStream;

  Stream<Duration?> get durationStream => player.durationStream;

  Duration? get duration => player.duration;

  Stream<bool> get playingStream => player.playingStream;

  bool get isPlaying => player.playing;

  // ============================================================
  // SHUFFLE
  // ============================================================

  bool get isShuffleEnabled => _shuffleEnabled;

  // ============================================================
  // REPEAT
  // ============================================================

  Stream<LoopMode> get loopModeStream async* {
    yield _repeatMode;
  }

  LoopMode get loopMode => _repeatMode;

  // ============================================================
  // PLAY SONG
  // ============================================================

  Future<void> playSong(Song song, {required List<Song> playlist}) async {
    _recentlyPlayed.addSong(song);
    if (song.path == null || song.path!.isEmpty) {
      return;
    }

    final validSongs = playlist
        .where((s) => s.path != null && s.path!.isNotEmpty)
        .toList();

    if (validSongs.isEmpty) {
      return;
    }

    _originalPlaylist = List<Song>.from(validSongs);

    _playlist = List<Song>.from(validSongs);

    _shufflePlaylist = [];

    _shuffleEnabled = false;

    final index = _playlist.indexWhere((s) => s.id == song.id);

    final startIndex = index >= 0 ? index : 0;

    currentSong = _playlist[startIndex];

    final sources = _playlist.map((song) {
      return AudioSource.file(song.path!);
    }).toList();

    await player.setAudioSources(
      sources,
      initialIndex: startIndex,
      initialPosition: Duration.zero,
    );

    await player.setLoopMode(LoopMode.off);

    await player.play();
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> resume() async {
    await player.play();
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  // ============================================================
  // PREVIOUS
  // ============================================================

  Future<void> previous() async {
    if (_playlist.isEmpty) {
      return;
    }

    final currentIndex = _playlist.indexWhere(
      (song) => song.id == currentSong?.id,
    );

    if (currentIndex < 0) {
      return;
    }

    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }

    int previousIndex = currentIndex - 1;

    if (previousIndex < 0) {
      if (_repeatMode == LoopMode.all) {
        previousIndex = _playlist.length - 1;
      } else {
        return;
      }
    }

    await _playFromPlaylist(previousIndex);
  }

  // ============================================================
  // NEXT
  // ============================================================

  Future<void> next() async {
    if (_playlist.isEmpty || currentSong == null) {
      return;
    }

    final currentIndex = _playlist.indexWhere(
      (song) => song.id == currentSong!.id,
    );

    if (currentIndex == -1) {
      return;
    }

    int nextIndex;

    if (_shuffleEnabled) {
      // Shuffle mode:
      // Always choose the song after the current song
      // in our manually shuffled playlist.
      nextIndex = currentIndex + 1;

      if (nextIndex >= _playlist.length) {
        if (_repeatMode == LoopMode.all) {
          nextIndex = 0;
        } else {
          return;
        }
      }
    } else {
      // Normal mode
      nextIndex = currentIndex + 1;

      if (nextIndex >= _playlist.length) {
        if (_repeatMode == LoopMode.all) {
          nextIndex = 0;
        } else {
          return;
        }
      }
    }

    await _playFromPlaylist(nextIndex);
  }

  Future<void> _playFromPlaylist(int index) async {
    if (index < 0 || index >= _playlist.length) {
      return;
    }

    final song = _playlist[index];

    if (song.path == null || song.path!.isEmpty) {
      return;
    }

    // Tell the UI exactly which song is being played.
    currentSong = song;

    // Load only this song.
    await player.setAudioSource(
      AudioSource.file(song.path!),
      initialPosition: Duration.zero,
    );

    // Start playback.
    await player.play();
  }
  // ============================================================
  // SONG COMPLETED
  // ============================================================

  Future<void> _handleSongCompleted() async {
    if (_playlist.isEmpty || currentSong == null) {
      return;
    }

    // ============================================================
    // REPEAT ONE
    // ============================================================

    if (_repeatMode == LoopMode.one) {
      await player.seek(Duration.zero);
      await player.play();
      return;
    }

    // Find current song in OUR playlist.
    final currentIndex = _playlist.indexWhere(
      (song) => song.id == currentSong!.id,
    );

    if (currentIndex < 0) {
      return;
    }

    // ============================================================
    // NEXT SONG
    // ============================================================

    int nextIndex = currentIndex + 1;

    // ============================================================
    // END OF PLAYLIST
    // ============================================================

    if (nextIndex >= _playlist.length) {
      if (_repeatMode == LoopMode.all) {
        nextIndex = 0;
      } else {
        await player.pause();
        return;
      }
    }

    // Play according to OUR playlist.
    await _playFromPlaylist(nextIndex);
  }

  // ============================================================
  // SHUFFLE
  // ============================================================

  Future<void> toggleShuffle() async {
    if (_originalPlaylist.isEmpty || currentSong == null) {
      return;
    }

    final current = currentSong!;

    _shuffleEnabled = !_shuffleEnabled;

    if (_shuffleEnabled) {
      final remaining = List<Song>.from(_originalPlaylist)
        ..removeWhere((song) => song.id == current.id);

      remaining.shuffle(Random());

      _shufflePlaylist = [current, ...remaining];

      // Use the shuffled playlist for Next/Previous.
      _playlist = List<Song>.from(_shufflePlaylist);
    } else {
      _shufflePlaylist = [];

      // Restore normal playlist.
      _playlist = List<Song>.from(_originalPlaylist);
    }
  }

  // ============================================================
  // REPEAT
  // ============================================================

  Future<void> cycleRepeatMode() async {
    switch (_repeatMode) {
      case LoopMode.off:
        _repeatMode = LoopMode.all;
        break;

      case LoopMode.all:
        _repeatMode = LoopMode.one;
        break;

      case LoopMode.one:
        _repeatMode = LoopMode.off;
        break;
    }

    // Do NOT use just_audio's LoopMode here.
    //
    // media_kit backend has caused compatibility issues
    // with some just_audio queue functionality.
    //
    // We handle repeat ourselves.
  }

  // ============================================================
  // SEEK
  // ============================================================

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  // ============================================================
  // VOLUME
  // ============================================================

  Future<void> setVolume(double volume) async {
    await player.setVolume(volume);
  }

  // ============================================================
  // STOP
  // ============================================================

  Future<void> stop() async {
    await player.stop();
    currentSong = null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await _processingSubscription?.cancel();
    await player.dispose();
    await _currentSongController.close();
  }
}
