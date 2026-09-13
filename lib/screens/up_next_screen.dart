import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';

class UpNextScreen extends StatelessWidget {
  const UpNextScreen({super.key});

  Widget _buildArtwork(BuildContext context, Song song, {double size = 50}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: song.artworkId == null
            ? Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.music_note, size: size * 0.5),
              )
            : QueryArtworkWidget(
                id: song.artworkId!,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                nullArtworkWidget: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.music_note, size: size * 0.5),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Up Next',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<Song?>(
        stream: player.currentSongStream,
        initialData: player.currentSong,
        builder: (context, songSnapshot) {
          return StreamBuilder<List<Song>>(
            stream: player.queueStream,
            initialData: player.queue,
            builder: (context, queueSnapshot) {
              final currentSong = songSnapshot.data;
              final queue = queueSnapshot.data ?? [];
              final currentIndex = player.currentIndex;

              if (queue.isEmpty && currentSong == null) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.queue_music, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Queue is empty',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final upcomingStartIndex =
                  currentIndex >= 0 ? currentIndex + 1 : 0;
              final upcomingCount = upcomingStartIndex < queue.length
                  ? queue.length - upcomingStartIndex
                  : 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Now Playing Section
                  if (currentSong != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Now Playing',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: _buildArtwork(context, currentSong),
                        title: Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          currentSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          Icons.volume_up,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                  ],

                  // Up Next Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Up Next',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          '$upcomingCount ${upcomingCount == 1 ? "song" : "songs"}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // Upcoming Songs List
                  Expanded(
                    child: upcomingCount == 0
                        ? const Center(
                            child: Text(
                              'No upcoming songs',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: upcomingCount,
                            itemBuilder: (context, index) {
                              final actualQueueIndex =
                                  upcomingStartIndex + index;
                              final song = queue[actualQueueIndex];

                              return ListTile(
                                leading: _buildArtwork(context, song),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Remove from queue',
                                  onPressed: () {
                                    player.removeFromQueue(actualQueueIndex);
                                  },
                                ),
                                onTap: () async {
                                  await player.playFromQueue(actualQueueIndex);
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
