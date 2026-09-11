import 'package:flutter/material.dart';
import '../../models/hymn.dart';
import '../../services/database_service.dart';
import '../../services/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/home_screen.dart';

class SavedHymnsTab extends StatefulWidget {
  final List<Map<String, dynamic>> savedHymns;
  final List<Map<String, dynamic>> playlists;
  final DatabaseService dbService;
  final VoidCallback onDataChanged;

  const SavedHymnsTab({
    super.key,
    required this.savedHymns,
    required this.playlists,
    required this.dbService,
    required this.onDataChanged,
  });

  @override
  State<SavedHymnsTab> createState() => _SavedHymnsTabState();
}

class _SavedHymnsTabState extends State<SavedHymnsTab> {
  bool _showPlaylists = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Playlist Toggle row
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Indirimbo zose (Favorites)', style: TextStyle(fontSize: 12)),
                  selected: !_showPlaylists,
                  onSelected: (_) => setState(() => _showPlaylists = false),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Urutonde rw\'indirimbo (Playlists)', style: TextStyle(fontSize: 12)),
                  selected: _showPlaylists,
                  onSelected: (_) => setState(() => _showPlaylists = true),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: _showPlaylists ? _buildPlaylistsTab() : _buildFavoritesHymnsTab(),
        ),
      ],
    );
  }

  Widget _buildFavoritesHymnsTab() {
    if (widget.savedHymns.isEmpty) {
      return _buildEmptyState(AppLocalizations.translate('saved_empty_hymns'));
    }

    final appColors = context.appColors;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.savedHymns.length,
      itemBuilder: (context, index) {
        final hymnMap = widget.savedHymns[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: appColors.accent.withValues(alpha: 0.1),
              child: Text(
                '#${hymnMap['number']}',
                style: TextStyle(color: appColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(hymnMap['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Igitabo: ${hymnMap['book']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await widget.dbService.removeFavorite('hymn', hymnMap['id']);
                widget.onDataChanged();
              },
            ),
            onTap: () {
              final hymnObj = Hymn.fromMap(hymnMap);
              final parentState = context.findAncestorStateOfType<HomeScreenState>();
              parentState?.navigateToHymn(hymnObj);
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Kora urutonde rushya (Create Playlist)'),
            onPressed: _showCreatePlaylistDialog,
          ),
        ),
        Expanded(
          child: widget.playlists.isEmpty
              ? const Center(child: Text('Nta ntonde z\'indirimbo ziriho.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.playlists.length,
                  itemBuilder: (context, index) {
                    final pl = widget.playlists[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.playlist_play, size: 28),
                        title: Text(
                          pl['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            await widget.dbService.deletePlaylist(pl['id']);
                            widget.onDataChanged();
                          },
                        ),
                        onTap: () => _showPlaylistSongsDialog(pl['id'], pl['name']),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kora Urutonde Rushya (Playlist)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Andika izina ry\'urutonde ry\'indirimbo...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Reka'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await widget.dbService.createPlaylist(name);
                widget.onDataChanged();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Kora'),
          ),
        ],
      ),
    );
  }

  void _showPlaylistSongsDialog(int playlistId, String playlistName) async {
    final hymns = await widget.dbService.getPlaylistHymns(playlistId);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Urutonde: $playlistName'),
              content: SizedBox(
                width: double.maxFinite,
                child: hymns.isEmpty
                    ? const Center(
                        child: Text(
                          'Nta ndirimbo ziri muri uru rutonde. Andika "+" ku ndirimbo yose ngo uyongeremo!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: hymns.length,
                        itemBuilder: (context, index) {
                          final song = hymns[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text('${song.number}'),
                            ),
                            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(song.book, style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () async {
                                await widget.dbService.removeHymnFromPlaylist(playlistId, song.id!);
                                final updated = await widget.dbService.getPlaylistHymns(playlistId);
                                setDialogState(() {
                                  hymns.clear();
                                  hymns.addAll(updated);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ikutse muri playlist!'), duration: Duration(seconds: 1)),
                                );
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context); // Close dialog
                              final parentState = context.findAncestorStateOfType<HomeScreenState>();
                              parentState?.navigateToHymn(song);
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Funga'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
