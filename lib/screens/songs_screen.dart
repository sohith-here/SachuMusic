import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import 'now_playing_screen.dart';
import '../services/favorites_service.dart';

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
                          leading: CircleAvatar(
                            child: Icon(
                              isCurrentSong
                                  ? Icons.play_arrow
                                  : Icons.music_note,
                            ),
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
                          trailing: IconButton(
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
