import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import '../screens/now_playing_screen.dart';
import '../services/audio_player_service.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;

    return StreamBuilder<Song?>(
      stream: player.currentSongStream,
      initialData: player.currentSong,
      builder: (context, songSnapshot) {
        final song = songSnapshot.data;

        if (song == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<bool>(
          stream: player.playingStream,
          initialData: player.isPlaying,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;

            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NowPlayingScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        // Album artwork
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: song.artworkId == null
                                ? Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainer,
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 24,
                                    ),
                                  )
                                : QueryArtworkWidget(
                                    id: song.artworkId!,
                                    type: ArtworkType.AUDIO,
                                    artworkFit: BoxFit.cover,
                                    nullArtworkWidget: Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainer,
                                      child: const Icon(
                                        Icons.music_note,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Song title and artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Previous button
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: player.previous,
                        ),

                        // Play/Pause button
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: player.togglePlayPause,
                        ),

                        // Next button
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.skip_next),
                          onPressed: player.next,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
