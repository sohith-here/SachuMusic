import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../services/playlist_service.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final PlaylistService _playlistService = PlaylistService.instance;

  void _showCreatePlaylistDialog(BuildContext context) {
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
              _handleCreate(dialogContext, controller.text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _handleCreate(dialogContext, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _handleCreate(BuildContext dialogContext, String text) {
    final name = text.trim();
    if (name.isEmpty) return;

    final created = _playlistService.createPlaylist(name);
    Navigator.pop(dialogContext);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlistId: created.id),
      ),
    );
  }

  void _showRenamePlaylistDialog(BuildContext context, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: playlist.name.length,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              _handleRename(dialogContext, playlist.id, controller.text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  _handleRename(dialogContext, playlist.id, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _handleRename(
    BuildContext dialogContext,
    String playlistId,
    String text,
  ) {
    final name = text.trim();
    if (name.isEmpty) return;

    final success = _playlistService.renamePlaylist(playlistId, name);
    if (success) {
      Navigator.pop(dialogContext);
    }
  }

  void _confirmDelete(BuildContext context, Playlist playlist) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Playlist'),
          content: Text('Are you sure you want to delete "${playlist.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _playlistService.deletePlaylist(playlist.id);
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Playlists',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Playlist',
            onPressed: () => _showCreatePlaylistDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePlaylistDialog(context),
        tooltip: 'Create Playlist',
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: _playlistService.changes,
        builder: (context, _, child) {
          final playlists = _playlistService.playlists;

          if (playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.queue_music, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No playlists yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreatePlaylistDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Playlist'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];

              return ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.queue_music, size: 28),
                ),
                title: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${playlist.songIds.length} ${playlist.songIds.length == 1 ? "song" : "songs"}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Rename playlist',
                      onPressed: () =>
                          _showRenamePlaylistDialog(context, playlist),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete playlist',
                      onPressed: () => _confirmDelete(context, playlist),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaylistDetailScreen(playlistId: playlist.id),
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
