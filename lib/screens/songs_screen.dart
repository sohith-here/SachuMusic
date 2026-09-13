import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import 'now_playing_screen.dart';
import '../services/favorites_service.dart';
import '../services/playlist_service.dart';

class SongsScreen extends StatefulWidget {
  final List<Song> songs;

  const SongsScreen({super.key, required this.songs});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final favorites = FavoritesService.instance;
  List<Song> get _filteredSongs {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      return widget.songs;
    }

    return widget.songs.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    final playlistService = PlaylistService.instance;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<int>(
          valueListenable: playlistService.changes,
          builder: (context, _, child) {
            final playlists = playlistService.playlists;

            return AlertDialog(
              title: const Text('Add to Playlist'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('New Playlist'),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _showCreateAndAddDialog(context, song);
                      },
                    ),
                    const Divider(),
                    if (playlists.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No playlists yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            final isInPlaylist =
                                playlist.songIds.contains(song.id);

                            return ListTile(
                              leading: const Icon(Icons.queue_music),
                              title: Text(
                                playlist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle:
                                  Text('${playlist.songIds.length} songs'),
                              trailing: isInPlaylist
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () {
                                final added =
                                    playlistService.addSongToPlaylist(
                                  playlist.id,
                                  song.id,
                                );
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      added
                                          ? 'Added "${song.title}" to ${playlist.name}'
                                          : '"${song.title}" is already in ${playlist.name}',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateAndAddDialog(BuildContext context, Song song) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              _createAndAdd(context, dialogContext, song, controller.text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _createAndAdd(context, dialogContext, song, controller.text);
              },
              child: const Text('Create & Add'),
            ),
          ],
        );
      },
    );
  }

  void _createAndAdd(
    BuildContext parentContext,
    BuildContext dialogContext,
    Song song,
    String text,
  ) {
    final name = text.trim();
    if (name.isEmpty) return;

    final newPlaylist = PlaylistService.instance.createPlaylist(name);
    PlaylistService.instance.addSongToPlaylist(newPlaylist.id, song.id);
    Navigator.pop(dialogContext);

    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text('Added "${song.title}" to ${newPlaylist.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'Search songs',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade700),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white),
            ),
            filled: true,
            fillColor: Colors.black12,
          ),
        ),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: favorites.changes,
        builder: (context, _, child) {
          return widget.songs.isEmpty
              ? const Center(child: Text('No music found'))
              : StreamBuilder<Song?>(
                  stream: player.currentSongStream,
                  initialData: player.currentSong,
                  builder: (context, snapshot) {
                    final currentSong = snapshot.data;

                    return ListView.builder(
                      itemCount: _filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = _filteredSongs[index];

                        final isCurrentSong = currentSong?.id == song.id;

                        return ListTile(
                          leading: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: song.artworkId == null
                                      ? Container(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: Icon(
                                            isCurrentSong
                                                ? Icons.play_arrow
                                                : Icons.music_note,
                                          ),
                                        )
                                      : QueryArtworkWidget(
                                          id: song.artworkId!,
                                          type: ArtworkType.AUDIO,
                                          artworkFit: BoxFit.cover,
                                          nullArtworkWidget: Container(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            child: Icon(
                                              isCurrentSong
                                                  ? Icons.play_arrow
                                                  : Icons.music_note,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              if (isCurrentSong && song.artworkId != null)
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrentSong
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.playlist_add),
                                tooltip: 'Add to playlist',
                                onPressed: () =>
                                    _showAddToPlaylistDialog(context, song),
                              ),
                              IconButton(
                                icon: Icon(
                                  favorites.isFavorite(song.id)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: favorites.isFavorite(song.id)
                                      ? Colors.red
                                      : null,
                                ),
                                onPressed: () {
                                  favorites.toggleFavorite(song.id);
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            await player.playSong(song, playlist: widget.songs);

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
                    );
                  },
                );
        },
      ),
    );
  }
}
