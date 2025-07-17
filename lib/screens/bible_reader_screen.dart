import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/app_state_service.dart';
import '../models/bible_book.dart';
import '../models/bible_verse.dart';
import '../models/bible_version.dart';

class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({super.key});

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  final DatabaseService _databaseService = DatabaseService();

  List<BibleBook> _books = [];
  List<BibleVerse> _verses = [];
  List<BibleVersion> _bibleVersions = [];

  BibleBook? _selectedBook;
  int _selectedChapter = 1;
  BibleVersion? _selectedVersion;

  bool _isLoading = true;
  bool _isLoadingVerses = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Load Bible versions
      final versions = await _databaseService.getBibleVersions();
      final downloadedVersions = versions.where((v) => v.isDownloaded).toList();

      if (downloadedVersions.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        _showNoDownloadedVersionsDialog();
        return;
      }

      // Get selected Bible language from preferences
      final selectedLanguage = await AppStateService.getBibleLanguage();
      BibleVersion? selectedVersion = downloadedVersions.firstWhere(
            (v) => v.versionCode.contains(selectedLanguage.split('_').last),
        orElse: () => downloadedVersions.first,
      );

      // Load books
      final books = await _databaseService.getBibleBooks();

      setState(() {
        _bibleVersions = downloadedVersions;
        _selectedVersion = selectedVersion;
        _books = books;
        _selectedBook = books.isNotEmpty ? books.first : null;
        _isLoading = false;
      });

      // Load verses for the first book and chapter
      if (_selectedBook != null && _selectedVersion != null) {
        await _loadVerses();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to load Bible data: $e');
    }
  }

  Future<void> _loadVerses() async {
    if (_selectedBook == null || _selectedVersion == null) return;

    setState(() {
      _isLoadingVerses = true;
    });

    try {
      final verses = await _databaseService.getChapterVerses(
        _selectedVersion!.id!,
        _selectedBook!.id!,
        _selectedChapter,
      );

      setState(() {
        _verses = verses;
        _isLoadingVerses = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingVerses = false;
      });
      _showErrorDialog('Failed to load verses: $e');
    }
  }

  void _showNoDownloadedVersionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Bible Downloaded'),
        content: const Text(
          'You need to download at least one Bible version to start reading. '
              'Go to Settings > Manage Downloads to download Bible versions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getBookName(BibleBook book, String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'rw':
        return book.bookNameKinyarwanda;
      case 'fr':
        return book.bookNameFrench;
      default:
        return book.bookNameEn;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedBook == null || _selectedVersion == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bible Reader'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'No Bible data available.\nPlease download a Bible version first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final bookName = _getBookName(_selectedBook!, _selectedVersion!.languageCode);

    return Scaffold(
      appBar: AppBar(
        title: Text('$bookName $_selectedChapter'),
        centerTitle: true,
        actions: [
          PopupMenuButton<BibleVersion>(
            icon: const Icon(Icons.translate),
            onSelected: (version) async {
              setState(() {
                _selectedVersion = version;
              });
              await AppStateService.setBibleLanguage(version.versionCode);
              await _loadVerses();
            },
            itemBuilder: (context) {
              return _bibleVersions.map((version) {
                return PopupMenuItem<BibleVersion>(
                  value: version,
                  child: Text(version.displayName),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Book and Chapter selector
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showBookSelector,
                    child: Text(bookName),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showChapterSelector,
                    child: Text('Chapter $_selectedChapter'),
                  ),
                ),
              ],
            ),
          ),

          // Verses display
          Expanded(
            child: _isLoadingVerses
                ? const Center(child: CircularProgressIndicator())
                : _verses.isEmpty
                ? const Center(
              child: Text(
                'No verses available for this chapter.',
                style: TextStyle(fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _verses.length,
              itemBuilder: (context, index) {
                final verse = _verses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GestureDetector(
                    onTap: () => _showVerseOptions(verse),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyLarge,
                        children: [
                          TextSpan(
                            text: '${verse.verseNumber} ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          TextSpan(
                            text: verse.verseText,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _selectedChapter > 1
                      ? () {
                    setState(() {
                      _selectedChapter--;
                    });
                    _loadVerses();
                  }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedChapter < (_selectedBook?.chapterCount ?? 1)
                      ? () {
                    setState(() {
                      _selectedChapter++;
                    });
                    _loadVerses();
                  }
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Select Book',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    final bookName = _getBookName(book, _selectedVersion!.languageCode);

                    return ListTile(
                      title: Text(bookName),
                      subtitle: Text('${book.chapterCount} chapters'),
                      onTap: () {
                        setState(() {
                          _selectedBook = book;
                          _selectedChapter = 1;
                        });
                        Navigator.pop(context);
                        _loadVerses();
                      },
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

  void _showChapterSelector() {
    if (_selectedBook == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Select Chapter',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedBook!.chapterCount,
                  itemBuilder: (context, index) {
                    final chapter = index + 1;
                    return ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedChapter = chapter;
                        });
                        Navigator.pop(context);
                        _loadVerses();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: chapter == _selectedChapter
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                      child: Text('$chapter'),
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

  void _showVerseOptions(BibleVerse verse) {
    final bookName = _getBookName(_selectedBook!, _selectedVersion!.languageCode);
    final reference = '$bookName ${verse.chapterNumber}:${verse.verseNumber}';

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reference,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                verse.verseText,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _shareVerse(verse, reference);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Implement bookmark functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bookmark feature coming soon!')),
                      );
                    },
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Bookmark'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareVerse(BibleVerse verse, String reference) {
    final text = '"${verse.verseText}"\n\n$reference';
    // Note: You'll need to add share_plus package for actual sharing
    // For now, just copy to clipboard or show the text
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing: $text')),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search'),
          content: const TextField(
            decoration: InputDecoration(
              hintText: 'Enter search terms...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Implement search functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search feature coming soon!')),
                );
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }
}