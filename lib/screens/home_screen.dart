import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/music_scanner.dart';
import 'now_playing_screen.dart';
import '../services/audio_player_service.dart';
import 'songs_screen.dart';
import '../services/recently_played_service.dart';
import 'main_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MusicScanner _scanner = MusicScanner();
  final AudioPlayerService _player = AudioPlayerService.instance;
  List<Song> _songs = [];
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
      _songs = songs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text(
                'Sachu Music',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SongsScreen(songs: _songs),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Text('Good afternoon', style: TextStyle(fontSize: 16)),

                  const SizedBox(height: 6),

                  const Text(
                    'What do you want to listen to?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Recently played',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  ValueListenableBuilder<int>(
                    valueListenable: RecentlyPlayedService.instance.changes,
                    builder: (context, _, child) {
                      final recentlyPlayed =
                          RecentlyPlayedService.instance.songs;

                      return SizedBox(
                        height: 180,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : recentlyPlayed.isEmpty
                            ? const Center(
                                child: Text('No recently played songs'),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: recentlyPlayed.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final song = recentlyPlayed[index];

                                  return GestureDetector(
                                    onTap: () async {
                                      await _player.playSong(
                                        song,
                                        playlist: recentlyPlayed,
                                      );

                                      if (!context.mounted) return;

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const NowPlayingScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 150,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.music_note,
                                              size: 48,
                                            ),
                                            const SizedBox(height: 12),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              child: Text(
                                                song.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your library',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_songs.length} songs',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  ListTile(
                    leading: const Icon(Icons.music_note),
                    title: const Text('Songs'),
                    subtitle: Text(
                      _isLoading
                          ? 'Scanning music...'
                          : '${_songs.length} songs',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SongsScreen(songs: _songs),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.favorite),
                    title: const Text('Favorites'),
                    subtitle: const Text('Your favorite songs'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: const Text('Playlists'),
                    subtitle: const Text('Your playlists'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
