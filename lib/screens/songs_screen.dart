import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import 'now_playing_screen.dart';

class SongsScreen extends StatefulWidget {
  final List<Song> songs;

  const SongsScreen({super.key, required this.songs});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Songs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: widget.songs.isEmpty
          ? const Center(child: Text('No music found'))
          : StreamBuilder<Song?>(
              stream: player.currentSongStream,
              initialData: player.currentSong,
              builder: (context, snapshot) {
                final currentSong = snapshot.data;

                return ListView.builder(
                  itemCount: widget.songs.length,
                  itemBuilder: (context, index) {
                    final song = widget.songs[index];

                    final isCurrentSong = currentSong?.id == song.id;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          isCurrentSong ? Icons.play_arrow : Icons.music_note,
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
            ),
    );
  }
}
