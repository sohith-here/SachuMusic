import 'dart:io';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../services/audio_player_service.dart';
import '../services/playback_history_service.dart';
import 'now_playing_screen.dart';

String formatPlayedAt(DateTime playedAt, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = current.difference(playedAt);

  if (difference.isNegative || difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24 && current.day == playedAt.day) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays == 1 ||
      (current.day - playedAt.day == 1 && difference.inHours < 48)) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[playedAt.month - 1];
    if (current.year == playedAt.year) {
      return '$month ${playedAt.day}';
    } else {
      return '$month ${playedAt.day}, ${playedAt.year}';
    }
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _showClearConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear Listening History'),
          content: const Text(
            'Are you sure you want to clear your listening history? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await PlaybackHistoryService.instance.clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyService = PlaybackHistoryService.instance;
    final player = AudioPlayerService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear history',
            onPressed: () => _showClearConfirmation(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: historyService.changes,
        builder: (context, _, child) {
          final history = historyService.history;

          if (history.isEmpty) {
            return const Center(
              child: Text(
                'No listening history yet',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final song = item.song;

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: song.artworkId == null
                        ? Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.music_note),
                          )
                        : QueryArtworkWidget(
                            id: song.artworkId!,
                            type: ArtworkType.AUDIO,
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(Icons.music_note),
                            ),
                          ),
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${song.artist} • ${formatPlayedAt(item.playedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  final path = song.path;
                  if (path == null ||
                      path.isEmpty ||
                      !File(path).existsSync()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('File no longer exists on device'),
                      ),
                    );
                    return;
                  }

                  await player.playSong(song, playlist: [song]);

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
