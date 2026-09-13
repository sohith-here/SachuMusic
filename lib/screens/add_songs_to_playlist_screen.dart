import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/music_scanner.dart';
import '../services/playlist_service.dart';

class AddSongsToPlaylistScreen extends StatefulWidget {
  final String playlistId;
  final List<Song>? initialSongs;

  const AddSongsToPlaylistScreen({
    super.key,
    required this.playlistId,
    this.initialSongs,
  });

  @override
  State<AddSongsToPlaylistScreen> createState() =>
      _AddSongsToPlaylistScreenState();
}

class _AddSongsToPlaylistScreenState extends State<AddSongsToPlaylistScreen> {
  final PlaylistService _playlistService = PlaylistService.instance;
  final MusicScanner _scanner = MusicScanner();
  final TextEditingController _searchController = TextEditingController();

  List<Song> _allSongs = [];
  bool _isLoading = true;
  final Set<String> _selectedSongIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialSongs != null && widget.initialSongs!.isNotEmpty) {
      _allSongs = widget.initialSongs!;
      _isLoading = false;
    } else {
      _loadSongs();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    final songs = await _scanner.scanSongs();
    if (!mounted) return;
    setState(() {
      _allSongs = songs;
      _isLoading = false;
    });
  }

  List<Song> get _filteredSongs {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      return _allSongs;
    }
    return _allSongs.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();
  }

  void _toggleSelection(String songId, bool isAlreadyInPlaylist) {
    if (isAlreadyInPlaylist) return;
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _addSelectedSongs(Playlist playlist) {
    if (_selectedSongIds.isEmpty) return;

    final addedCount = _playlistService.addSongsToPlaylist(
      playlist.id,
      _selectedSongIds.toList(),
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added $addedCount ${addedCount == 1 ? "song" : "songs"} to ${playlist.name}',
        ),
        duration: const Duration(seconds: 2),
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
            appBar: AppBar(title: const Text('Add Songs')),
            body: const Center(child: Text('Playlist not found')),
          );
        }

        final existingIds = playlist.songIds.toSet();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add Songs'),
            actions: [
              if (_selectedSongIds.isNotEmpty)
                TextButton(
                  onPressed: () => _addSelectedSongs(playlist),
                  child: Text(
                    'Add (${_selectedSongIds.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          floatingActionButton: _selectedSongIds.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _addSelectedSongs(playlist),
                  icon: const Icon(Icons.check),
                  label: Text(
                    'Add ${_selectedSongIds.length} ${_selectedSongIds.length == 1 ? "song" : "songs"}',
                  ),
                ),
          body: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search songs',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSongs.isEmpty
                        ? const Center(child: Text('No songs found'))
                        : ListView.builder(
                            itemCount: _filteredSongs.length,
                            itemBuilder: (context, index) {
                              final song = _filteredSongs[index];
                              final isAlreadyInPlaylist =
                                  existingIds.contains(song.id);
                              final isSelected =
                                  _selectedSongIds.contains(song.id);

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
                                            child:
                                                const Icon(Icons.music_note),
                                          )
                                        : QueryArtworkWidget(
                                            id: song.artworkId!,
                                            type: ArtworkType.AUDIO,
                                            artworkFit: BoxFit.cover,
                                            nullArtworkWidget: Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                  Icons.music_note),
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isAlreadyInPlaylist
                                        ? Colors.grey
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isAlreadyInPlaylist
                                        ? Colors.grey.shade600
                                        : null,
                                  ),
                                ),
                                trailing: isAlreadyInPlaylist
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 18,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'In playlist',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Checkbox(
                                        value: isSelected,
                                        onChanged: (_) => _toggleSelection(
                                          song.id,
                                          isAlreadyInPlaylist,
                                        ),
                                      ),
                                onTap: isAlreadyInPlaylist
                                    ? null
                                    : () => _toggleSelection(
                                          song.id,
                                          isAlreadyInPlaylist,
                                        ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
