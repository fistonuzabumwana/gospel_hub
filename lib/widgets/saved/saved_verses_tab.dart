import 'package:flutter/material.dart';
import '../../models/bible_book.dart';
import '../../services/database_service.dart';
import '../../services/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/home_screen.dart';

class SavedVersesTab extends StatelessWidget {
  final List<Map<String, dynamic>> savedVerses;
  final DatabaseService dbService;
  final VoidCallback onDataChanged;

  const SavedVersesTab({
    super.key,
    required this.savedVerses,
    required this.dbService,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (savedVerses.isEmpty) {
      return _buildEmptyState(AppLocalizations.translate('saved_empty_verses'));
    }

    final appColors = context.appColors;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: savedVerses.length,
      itemBuilder: (context, index) {
        final verseMap = savedVerses[index];
        final bookObj = BibleBook.getByNumber(verseMap['book']);
        final refStr = '${bookObj.name} ${verseMap['chapter']}:${verseMap['verse']}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              verseMap['text'],
              style: const TextStyle(fontSize: 15, fontFamily: 'serif', height: 1.5),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                refStr,
                style: TextStyle(fontWeight: FontWeight.bold, color: appColors.accent),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await dbService.removeFavorite('bible', verseMap['id']);
                onDataChanged();
              },
            ),
            onTap: () {
              final parentState = context.findAncestorStateOfType<HomeScreenState>();
              parentState?.navigateToBibleVerse(bookObj, verseMap['chapter'], verseMap['verse']);
            },
          ),
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
