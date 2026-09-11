import 'package:flutter/material.dart';
import '../../models/bible_book.dart';
import '../../services/database_service.dart';

class BibleNavigationModals {
  static void showBookSelector(
    BuildContext context, {
    required String translationMode,
    required BibleBook selectedBook,
    required List<int> availableBookNumbers,
    required DatabaseService dbService,
    required ValueNotifier<String> activeKinyarwandaBibleNotifier,
    required void Function(BibleBook, int, int) onVerseSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final primaryColor = Theme.of(context).primaryColor;
              final accentColor = isDark ? const Color(0xFF60A5FA) : primaryColor;
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: TabBar(
                      indicatorColor: accentColor,
                      labelColor: accentColor,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(text: translationMode == 'english' ? 'Old Testament' : 'Isezerano rya Kera'),
                        Tab(text: translationMode == 'english' ? 'New Testament' : 'Isezerano Rishya'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBookGrid(
                          context,
                          BibleBook.allBooks.where((b) => b.isOldTestament).toList(),
                          scrollController,
                          availableBookNumbers,
                          selectedBook,
                          translationMode,
                          dbService,
                          activeKinyarwandaBibleNotifier,
                          onVerseSelected,
                        ),
                        _buildBookGrid(
                          context,
                          BibleBook.allBooks.where((b) => !b.isOldTestament).toList(),
                          scrollController,
                          availableBookNumbers,
                          selectedBook,
                          translationMode,
                          dbService,
                          activeKinyarwandaBibleNotifier,
                          onVerseSelected,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static Widget _buildBookGrid(
    BuildContext context,
    List<BibleBook> books,
    ScrollController controller,
    List<int> availableBookNumbers,
    BibleBook selectedBook,
    String translationMode,
    DatabaseService dbService,
    ValueNotifier<String> activeKinyarwandaBibleNotifier,
    void Function(BibleBook, int, int) onVerseSelected,
  ) {
    final displayBooks = availableBookNumbers.isEmpty
        ? books
        : books.where((b) => availableBookNumbers.contains(b.bookNumber)).toList();

    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: displayBooks.length,
      itemBuilder: (context, index) {
        final book = displayBooks[index];
        final isSelected = book.bookNumber == selectedBook.bookNumber;

        return Card(
          color: isSelected ? Theme.of(context).primaryColor : null,
          elevation: isSelected ? 4 : 1,
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
              showChapterSelector(
                context, 
                book: book, 
                dbService: dbService, 
                activeKinyarwandaBibleNotifier: activeKinyarwandaBibleNotifier, 
                onVerseSelected: onVerseSelected
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                book.getDisplayName(translationMode),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : null,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  static void showChapterSelector(
    BuildContext context, {
    required BibleBook book,
    required DatabaseService dbService,
    required ValueNotifier<String> activeKinyarwandaBibleNotifier,
    required void Function(BibleBook, int, int) onVerseSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hitamo Igice cya: ${book.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: book.chapterCount,
                  itemBuilder: (context, index) {
                    final chapter = index + 1;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        showVerseSelector(
                          context,
                          book: book,
                          chapter: chapter,
                          dbService: dbService,
                          activeKinyarwandaBibleNotifier: activeKinyarwandaBibleNotifier,
                          onVerseSelected: onVerseSelected,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$chapter',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
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

  static void showVerseSelector(
    BuildContext context, {
    required BibleBook book,
    required int chapter,
    required DatabaseService dbService,
    required ValueNotifier<String> activeKinyarwandaBibleNotifier,
    required void Function(BibleBook, int, int) onVerseSelected,
  }) async {
    final verses = await dbService.getChapterVerses(book.bookNumber, chapter, translation: activeKinyarwandaBibleNotifier.value);
    final verseCount = verses.length;
    
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hitamo Umurongo: ${book.name} $chapter',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: verseCount,
                  itemBuilder: (context, index) {
                    final verseNum = index + 1;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        onVerseSelected(book, chapter, verseNum);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$verseNum',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
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
