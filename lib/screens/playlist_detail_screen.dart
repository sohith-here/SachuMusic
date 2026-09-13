import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/music_scanner.dart';
import '../services/playlist_service.dart';
import 'add_songs_to_playlist_screen.dart';
import 'now_playing_screen.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final AudioPlayerService _player = AudioPlayerService.instance;
  final PlaylistService _playlistService = PlaylistService.instance;
  final MusicScanner _scanner = MusicScanner();

  List<Song> _scannedSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final songs = await _scanner.scanSongs();
    if (!mounted) return;
    setState(() {
      _scannedSongs = songs;
      _isLoading = false;
    });
  }

  void _openAddSongs(BuildContext context, String playlistId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSongsToPlaylistScreen(
          playlistId: playlistId,
          initialSongs: _scannedSongs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _playlistService.changes,
      builder: (context, _, child) {
        final playlist = _playlistService.getPlaylist(widget.playlistId);

        if (playlist == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Playlist'),
            ),
            body: const Center(
              child: Text('Playlist not found'),
            ),
          );
        }

        final songMap = {for (final s in _scannedSongs) s.id: s};
        final resolvedSongs = <Song>[];
        for (final songId in playlist.songIds) {
          final song = songMap[songId];
          if (song != null) {
            resolvedSongs.add(song);
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${resolvedSongs.length} ${resolvedSongs.length == 1 ? "song" : "songs"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: 'Add Songs',
                onPressed: () => _openAddSongs(context, playlist.id),
              ),
              if (resolvedSongs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Play all',
                  onPressed: () async {
                    await _player.playSong(
                      resolvedSongs.first,
                      playlist: resolvedSongs,
                    );
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NowPlayingScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddSongs(context, playlist.id),
            icon: const Icon(Icons.add),
            label: const Text('Add Songs'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : resolvedSongs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.queue_music,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No songs in this playlist',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _openAddSongs(context, playlist.id),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Songs'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: resolvedSongs.length,
                      itemBuilder: (context, index) {
                        final song = resolvedSongs[index];

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
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            tooltip: 'Remove from playlist',
                            onPressed: () {
                              _playlistService.removeSongFromPlaylist(
                                playlist.id,
                                song.id,
                              );
                            },
                          ),
                          onTap: () async {
                            await _player.playSong(
                              song,
                              playlist: resolvedSongs,
                            );
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NowPlayingScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
        );
      },
    );
  }
}
