import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/favorites_service.dart';
import '../services/playback_history_service.dart';
import '../services/playlist_service.dart';

String formatTotalDuration(Duration duration) {
  if (duration.inSeconds <= 0) {
    return '0m';
  }
  if (duration.inSeconds < 60) {
    return '< 1m';
  }

  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);

  if (days >= 1) {
    if (hours > 0) {
      return '${days}d ${hours}h';
    }
    return '${days}d';
  } else if (duration.inHours >= 1) {
    if (minutes > 0) {
      return '${duration.inHours}h ${minutes}m';
    }
    return '${duration.inHours}h';
  } else {
    return '${duration.inMinutes}m';
  }
}

class StatisticsScreen extends StatelessWidget {
  final List<Song> songs;

  const StatisticsScreen({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    final favoritesService = FavoritesService.instance;
    final playlistService = PlaylistService.instance;
    final historyService = PlaybackHistoryService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          favoritesService.changes,
          playlistService.changes,
          historyService.changes,
        ]),
        builder: (context, _) {
          final totalSongs = songs.length;
          final totalLibraryDuration = songs.fold<Duration>(
            Duration.zero,
            (prev, s) => prev + s.duration,
          );

          final favoriteSongs = songs
              .where((s) => favoritesService.isFavorite(s.id))
              .length;

          final playlists = playlistService.playlists.length;
          final songsInPlaylists = playlistService.playlists.fold<int>(
            0,
            (prev, p) => prev + p.songIds.length,
          );

          final recordedPlays = historyService.count;
          final totalListeningTime = historyService.history.fold<Duration>(
            Duration.zero,
            (prev, item) => prev + item.song.duration,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                icon: Icons.music_note,
                title: 'Library',
                metrics: [
                  _StatMetric(value: '$totalSongs', label: 'Total Songs'),
                  _StatMetric(
                    value: formatTotalDuration(totalLibraryDuration),
                    label: 'Total Library Duration',
                  ),
                ],
              ),
              _StatCard(
                icon: Icons.favorite,
                iconColor: Colors.redAccent,
                title: 'Favorites',
                metrics: [
                  _StatMetric(value: '$favoriteSongs', label: 'Favorite Songs'),
                ],
              ),
              _StatCard(
                icon: Icons.queue_music,
                title: 'Playlists',
                metrics: [
                  _StatMetric(value: '$playlists', label: 'Playlists'),
                  _StatMetric(
                    value: '$songsInPlaylists',
                    label: 'Songs in Playlists',
                  ),
                ],
              ),
              _StatCard(
                icon: Icons.history,
                title: 'Listening History',
                metrics: [
                  _StatMetric(value: '$recordedPlays', label: 'Recorded Plays'),
                  _StatMetric(
                    value: formatTotalDuration(totalListeningTime),
                    label: 'Total Listening Time',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final List<Widget> metrics;

  const _StatCard({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: iconColor ?? theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: metrics.map((m) => Expanded(child: m)).toList()),
          ],
        ),
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  final String value;
  final String label;

  const _StatMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
