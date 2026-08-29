import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/favorites_service.dart';

import 'package:just_audio/just_audio.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final AudioPlayerService _player = AudioPlayerService.instance;
  final FavoritesService _favorites = FavoritesService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing'), centerTitle: true),
      body: StreamBuilder<Song?>(
        stream: _player.currentSongStream,
        initialData: _player.currentSong,
        builder: (context, snapshot) {
          final song = snapshot.data;

          if (song == null) {
            return const Center(child: Text('No song playing'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;

              // Responsive artwork size.
              final artworkSize = height < 650
                  ? (height * 0.32).clamp(160.0, 220.0)
                  : 280.0;

              // Responsive spacing.
              final largeSpacing = height < 650 ? 16.0 : 36.0;
              final bottomSpacing = height < 650 ? 12.0 : 28.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Album artwork
                      Container(
                        width: artworkSize,
                        height: artworkSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                        child: Icon(Icons.music_note, size: artworkSize * 0.36),
                      ),

                      SizedBox(height: largeSpacing),

                      // Song title
                      Text(
                        song.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: height < 650 ? 22 : 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Artist
                      Text(
                        song.artist,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),

                      SizedBox(height: largeSpacing),

                      // Progress
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        initialData: Duration.zero,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;

                          return StreamBuilder<Duration?>(
                            stream: _player.durationStream,
                            initialData: _player.duration,
                            builder: (context, durationSnapshot) {
                              final duration =
                                  durationSnapshot.data ?? Duration.zero;

                              final durationMs = duration.inMilliseconds;

                              final max = durationMs > 0
                                  ? durationMs.toDouble()
                                  : 1.0;

                              final value = position.inMilliseconds
                                  .clamp(0, durationMs > 0 ? durationMs : 1)
                                  .toDouble();

                              return Column(
                                children: [
                                  Slider(
                                    value: value,
                                    min: 0,
                                    max: max,
                                    onChanged: durationMs <= 0
                                        ? null
                                        : (newValue) {
                                            _player.seek(
                                              Duration(
                                                milliseconds: newValue.toInt(),
                                              ),
                                            );
                                          },
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(position)),
                                      Text(_formatDuration(duration)),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Controls
                      StreamBuilder<bool>(
                        stream: _player.playingStream,
                        initialData: _player.isPlaying,
                        builder: (context, playingSnapshot) {
                          final isPlaying = playingSnapshot.data ?? false;

                          return StreamBuilder<LoopMode>(
                            stream: _player.loopModeStream,
                            initialData: _player.loopMode,
                            builder: (context, loopSnapshot) {
                              final loopMode =
                                  loopSnapshot.data ?? LoopMode.off;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // ==================================================
                                  // SHUFFLE
                                  // ==================================================

                                  IconButton(
                                    onPressed: () async {
                                      await _player.toggleShuffle();

                                      if (!context.mounted) return;

                                      final enabled = _player.isShuffleEnabled;

                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            enabled
                                                ? 'Shuffle On'
                                                : 'Shuffle Off',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );

                                      setState(() {});
                                    },
                                    iconSize: 32,
                                    color: _player.isShuffleEnabled
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    icon: const Icon(Icons.shuffle),
                                  ),

                                  const SizedBox(width: 12),

                                  // ==================================================
                                  // PREVIOUS
                                  // ==================================================
                                  IconButton(
                                    onPressed: _player.previous,
                                    iconSize: 42,
                                    icon: const Icon(Icons.skip_previous),
                                  ),

                                  const SizedBox(width: 12),

                                  // ==================================================
                                  // PLAY / PAUSE
                                  // ==================================================
                                  FilledButton(
                                    onPressed: _player.togglePlayPause,
                                    style: FilledButton.styleFrom(
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(20),
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      size: 36,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // ==================================================
                                  // NEXT
                                  // ==================================================
                                  IconButton(
                                    onPressed: _player.next,
                                    iconSize: 42,
                                    icon: const Icon(Icons.skip_next),
                                  ),

                                  const SizedBox(width: 12),

                                  // ==================================================
                                  // REPEAT
                                  // ==================================================
                                  IconButton(
                                    onPressed: () async {
                                      await _player.cycleRepeatMode();

                                      if (!context.mounted) return;

                                      String message;

                                      switch (_player.loopMode) {
                                        case LoopMode.off:
                                          message = 'Repeat Off';
                                          break;

                                        case LoopMode.all:
                                          message = 'Repeat All';
                                          break;

                                        case LoopMode.one:
                                          message = 'Repeat One';
                                          break;
                                      }

                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(message),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );

                                      setState(() {});
                                    },
                                    iconSize: 32,
                                    color: loopMode != LoopMode.off
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    icon: Icon(
                                      loopMode == LoopMode.one
                                          ? Icons.repeat_one
                                          : Icons.repeat,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      SizedBox(height: bottomSpacing),

                      // Favorite
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _favorites.toggleFavorite(song.id);
                          });
                        },
                        iconSize: 28,
                        color: _favorites.isFavorite(song.id)
                            ? Colors.red
                            : null,
                        icon: Icon(
                          _favorites.isFavorite(song.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
