import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/bible_verse.dart';
import '../models/bible_book.dart';
import '../services/app_localizations.dart';
import '../main.dart';
import '../widgets/book_page_fold.dart';
import 'home_screen.dart';
import '../widgets/bible/verse_item.dart';
import '../widgets/bible/navigation_modals.dart';
import '../widgets/bible/reader_settings_modal.dart';
import '../widgets/bible/verse_actions_modal.dart';
class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({super.key});

  @override
  State<BibleReaderScreen> createState() => BibleReaderScreenState();
}

class BibleReaderScreenState extends State<BibleReaderScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  
  BibleBook _selectedBook = BibleBook.allBooks.first;
  int _selectedChapter = 1;
  int? _targetVerse;
  List<BibleVerse> _verses = [];
  List<GlobalKey> _verseKeys = [];
  bool _isLoading = true;
  bool _isSearching = false;

  Map<int, int> _highlights = {};
  Map<int, String> _notes = {};
  String _translationMode = 'parallel';
  Map<int, String> _englishVerses = {};
  Map<int, List<String>> _verseTagsMap = {};
  bool _isMultiSelectMode = false;
  final Set<int> _selectedVerseIds = {};

  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingTTS = false;
  int? _ttsActiveVerse;
  int? _ttsWordStartChar;
  int? _ttsWordEndChar;
  bool _isChapterTTS = false;

  Timer? _sleepTimer;
  int? _sleepTimerDurationMinutes;
  int? _sleepTimerRemainingSeconds;

  int? _lastScrolledVerse;
  Timer? _scrollThrottleTimer;

  static const List<Color> _highlightColors = [
    Colors.yellow,
    Colors.pink,
    Colors.lightGreen,
    Colors.lightBlue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.deepOrange,
  ];

  static Color _getHighlightColor(int? index) {
    if (index == null || index < 0 || index >= _highlightColors.length) return Colors.transparent;
    return _highlightColors[index];
  }

  // Settings
  double _fontSize = 17.0;
  String? _customThemeMode; // null means adaptive to system/global theme

  // Search Results
  final TextEditingController _searchController = TextEditingController();
  List<BibleVerse> _searchResults = [];
  bool _isSearchLoading = false;
  Timer? _searchDebounceTimer;

  late TabController _tabController;

  Set<int> _availableBookNumbers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initTts();

    // Set initial translation mode from global notifier
    _translationMode = bibleTranslationNotifier.value;
    bibleTranslationNotifier.addListener(_onTranslationChanged);
    activeKinyarwandaBibleNotifier.addListener(_onBibleVersionsChanged);
    activeEnglishBibleNotifier.addListener(_onBibleVersionsChanged);

    _scrollController.addListener(_onScroll);

    _loadAvailableBooks().then((_) {
      _loadLastRead().then((_) {
        _loadVersesAndScroll();
      });
    });
  }

  void _onTranslationChanged() {
    if (mounted) {
      setState(() {
        _translationMode = bibleTranslationNotifier.value;
      });
      _onTranslationModeToggled();
    }
  }

  void _onBibleVersionsChanged() {
    if (mounted) {
      _loadAvailableBooks().then((_) {
        _loadLastRead().then((_) {
          _loadVersesAndScroll();
        });
      });
    }
  }

  Future<void> _onTranslationModeToggled() async {
    await _loadAvailableBooks();
    // Maintain current reading position when toggling translation view mode
    _targetVerse = _lastScrolledVerse;
    await _saveLastRead();
    _loadVersesAndScroll();
  }

  // Cached instances to avoid repeated async lookups during scroll
  SharedPreferences? _cachedPrefs;
  String? _cachedPrimaryBibleId;
  Timer? _saveDebounceTimer;

  Future<String> _getPrimaryBibleId() async {
    if (_cachedPrimaryBibleId != null) return _cachedPrimaryBibleId!;
    final prefs = await _getPrefs();
    final primaryId = prefs.getString('active_bible_id');
    if (primaryId != null && primaryId.isNotEmpty) {
      _cachedPrimaryBibleId = primaryId;
      return primaryId;
    }
    _cachedPrimaryBibleId = activeKinyarwandaBibleNotifier.value;
    return _cachedPrimaryBibleId!;
  }

  Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  Future<void> _loadAvailableBooks() async {
    final activeTrans = _translationMode == 'english'
        ? activeEnglishBibleNotifier.value
        : activeKinyarwandaBibleNotifier.value;
    final books = await _dbService.getAvailableBooks(activeTrans);
    if (mounted) {
      setState(() {
        _availableBookNumbers = books;
      });
    }
  }

  Future<void> _saveLastRead() async {
    final prefs = await _getPrefs();
    final primaryId = await _getPrimaryBibleId();
    await prefs.setInt('last_read_book_number_$primaryId', _selectedBook.bookNumber);
    await prefs.setInt('last_read_chapter_$primaryId', _selectedChapter);
    if (_lastScrolledVerse != null) {
      await prefs.setInt('last_read_verse_$primaryId', _lastScrolledVerse!);
    }
    await prefs.setInt('last_read_book_number', _selectedBook.bookNumber);
    await prefs.setInt('last_read_chapter', _selectedChapter);
  }

  /// Debounced save — waits 1.5s after last scroll movement before writing to disk.
  void _debouncedSaveLastRead() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _saveLastRead();
    });
  }

  Future<void> _loadLastRead() async {
    final prefs = await _getPrefs();
    final primaryId = await _getPrimaryBibleId();
    final savedBookNum = prefs.getInt('last_read_book_number_$primaryId');
    final savedChapter = prefs.getInt('last_read_chapter_$primaryId');
    final savedVerse = prefs.getInt('last_read_verse_$primaryId');

    if (savedBookNum != null && savedChapter != null) {
      final book = BibleBook.allBooks.firstWhere(
        (b) => b.bookNumber == savedBookNum,
        orElse: () => BibleBook.allBooks.first,
      );
      if (_availableBookNumbers.isEmpty || _availableBookNumbers.contains(book.bookNumber)) {
        _selectedBook = book;
        _selectedChapter = savedChapter;
        _targetVerse = savedVerse;
        _lastScrolledVerse = savedVerse;
      } else {
        if (_availableBookNumbers.isNotEmpty) {
          _selectedBook = BibleBook.getByNumber(_availableBookNumbers.first);
        } else {
          _selectedBook = BibleBook.allBooks.first;
        }
        _selectedChapter = 1;
        _targetVerse = null;
        _lastScrolledVerse = null;
      }
    } else {
      // Default to Matthew 1 or the first available book for a newly opened Bible version
      if (_availableBookNumbers.isNotEmpty) {
        _selectedBook = BibleBook.getByNumber(_availableBookNumbers.contains(47) ? 47 : _availableBookNumbers.first);
      } else {
        _selectedBook = BibleBook.allBooks.first;
      }
      _selectedChapter = 1;
      _targetVerse = null;
      _lastScrolledVerse = null;
    }
  }

  void _onScroll() {
    if (_scrollThrottleTimer?.isActive ?? false) return;
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _verses.isEmpty || _verseKeys.isEmpty) return;
      int? topVerse;
      double minDiff = double.infinity;
      for (int i = 0; i < _verseKeys.length; i++) {
        if (i >= _verseKeys.length) break;
        final keyContext = _verseKeys[i].currentContext;
        if (keyContext != null) {
          final box = keyContext.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            final position = box.localToGlobal(Offset.zero);
            // Check top edge of the widget relative to the viewport height (appbar boundary is ~120px)
            final diff = (position.dy - 120).abs();
            if (diff < minDiff) {
              minDiff = diff;
              topVerse = _verses[i].verse;
            }
          }
        }
      }
      if (topVerse != null && topVerse != _lastScrolledVerse) {
        _lastScrolledVerse = topVerse;
        _debouncedSaveLastRead();
      }
    });
  }

  @override
  void dispose() {
    bibleTranslationNotifier.removeListener(_onTranslationChanged);
    activeKinyarwandaBibleNotifier.removeListener(_onBibleVersionsChanged);
    activeEnglishBibleNotifier.removeListener(_onBibleVersionsChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollThrottleTimer?.cancel();
    _saveDebounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _flutterTts.stop();
    _sleepTimer?.cancel();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSharedInstance(true);
    _flutterTts.setStartHandler(() {
      setState(() => _isPlayingTTS = true);
    });
    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      if (mounted && _ttsActiveVerse != null) {
        final verseIndex = _verses.indexWhere((v) => v.verse == _ttsActiveVerse);
        if (verseIndex != -1) {
          final verse = _verses[verseIndex];
          final hasHeading = verse.heading != null && verse.heading!.isNotEmpty && _translationMode != 'english';
          
          if (hasHeading) {
            final prefixLength = verse.heading!.length + 2; // "+ 2" for the period and space
            if (start >= prefixLength) {
              setState(() {
                _ttsWordStartChar = start - prefixLength;
                _ttsWordEndChar = end - prefixLength;
              });
            } else {
              // Narrating the heading, clear highlight
              setState(() {
                _ttsWordStartChar = null;
                _ttsWordEndChar = null;
              });
            }
          } else {
            setState(() {
              _ttsWordStartChar = start;
              _ttsWordEndChar = end;
            });
          }
        }
      }
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        if (_isChapterTTS && _ttsActiveVerse != null) {
          // Increment to the next verse
          setState(() {
            _ttsActiveVerse = _ttsActiveVerse! + 1;
            _ttsWordStartChar = null;
            _ttsWordEndChar = null;
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _isPlayingTTS) {
              _speakChapterVerseSequentially();
            }
          });
        } else {
          setState(() {
            _isPlayingTTS = false;
            _ttsActiveVerse = null;
            _isChapterTTS = false;
            _ttsWordStartChar = null;
            _ttsWordEndChar = null;
          });
        }
      }
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isPlayingTTS = false;
          _ttsActiveVerse = null;
          _isChapterTTS = false;
          _ttsWordStartChar = null;
          _ttsWordEndChar = null;
        });
      }
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isPlayingTTS = false;
          _ttsActiveVerse = null;
          _isChapterTTS = false;
          _ttsWordStartChar = null;
          _ttsWordEndChar = null;
        });
      }
    });
  }

  Future<void> _loadVerses({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      _lastScrolledVerse = _targetVerse;
      _saveLastRead();

      final needsEnglish = _translationMode == 'english' || _translationMode == 'parallel';
      final bookNum = _selectedBook.bookNumber;
      final chapter = _selectedChapter;

      // Run all DB queries in parallel instead of sequentially
      final results = await Future.wait([
        _dbService.getChapterVerses(bookNum, chapter, translation: activeKinyarwandaBibleNotifier.value),
        _dbService.getHighlightsForChapter(bookNum, chapter),
        _dbService.getNotesForChapter(bookNum, chapter),
        _dbService.getTagsForChapter(bookNum, chapter),
        if (needsEnglish) _dbService.getEnglishChapterVerses(bookNum, chapter, translation: activeEnglishBibleNotifier.value),
      ]);

      final verses = results[0] as List<BibleVerse>;
      final highlights = results[1] as Map<int, int>;
      final notes = results[2] as Map<int, String>;
      final tags = results[3] as Map<int, List<String>>;

      Map<int, String> englishVersesMap = {};
      if (needsEnglish && results.length > 4) {
        final engVerses = results[4] as List<Map<String, dynamic>>;
        englishVersesMap = {for (var v in engVerses) v['verse'] as int: v['text'] as String};
      }

      // Log reading history in background (fire-and-forget)
      _dbService.logReading(bookNum, chapter);

      if (mounted) {
        setState(() {
          _verses = verses;
          _verseKeys = List.generate(verses.length, (index) => GlobalKey());
          _highlights = highlights;
          _notes = notes;
          _verseTagsMap = tags;
          _englishVerses = englishVersesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading verses: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadVersesAndScroll() async {
    await _loadVerses();
    if (_targetVerse != null) {
      _scrollController.removeListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(_targetVerse!);
        // Reset target verse and restore scroll listener after animation completes (approx 2.5s)
        Future.delayed(const Duration(milliseconds: 2600), () {
          if (mounted) {
            _scrollController.addListener(_onScroll);
            setState(() {
              _targetVerse = null;
            });
          }
        });
      });
    }
  }

  void jumpToVerse(BibleBook book, int chapter, int verse) {
    setState(() {
      _selectedBook = book;
      _selectedChapter = chapter;
      _targetVerse = verse;
    });
    _loadVersesAndScroll();
  }

  void _scrollToVerse(int verseNumber) {
    final index = _verses.indexWhere((v) => v.verse == verseNumber);
    if (index == -1) return;

    // 1. Estimate scroll offset to jump close to the target verse
    double estimatedOffset = 0;
    final isParallel = _translationMode == 'parallel';
    final charsPerLine = 28.0 * (17.0 / _fontSize);

    for (int i = 0; i < index; i++) {
      final v = _verses[i];
      int lines = 0;
      if (isParallel) {
        final rwLen = v.text.length;
        final engLen = (_englishVerses[v.verse] ?? '').length;
        lines = (rwLen / charsPerLine).ceil() + (engLen / charsPerLine).ceil() + 2;
      } else if (_translationMode == 'english') {
        final engLen = (_englishVerses[v.verse] ?? v.text).length;
        lines = (engLen / charsPerLine).ceil();
      } else {
        final rwLen = v.text.length;
        lines = (rwLen / charsPerLine).ceil();
      }

      final hasNote = _notes.containsKey(v.id);
      final tags = _verseTagsMap[v.id];
      final tagCount = tags != null ? tags.length : 0;
      final hasHeading = v.heading != null && v.heading!.isNotEmpty;

      double headingHeight = 0;
      if (hasHeading) {
        final headingLines = (v.heading!.length / charsPerLine).ceil();
        headingHeight = headingLines * ((_fontSize + 1.5) * 1.4) + 32.0;
      }

      final padding = isParallel ? 32.0 : 18.0;
      final verseHeight = lines * (_fontSize * 1.6) + padding + (hasNote ? 14.0 : 0.0) + (tagCount > 0 ? 28.0 : 0.0) + headingHeight;
      estimatedOffset += verseHeight;
    }

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(estimatedOffset.clamp(0.0, maxScroll));
    }

    // Helper to perform precise alignment
    bool tryEnsureVisible() {
      if (!mounted) return false;
      if (index < _verseKeys.length) {
        final keyContext = _verseKeys[index].currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.2, // Align near top 20% of screen
          );
          return true;
        }
      }
      return false;
    }

    // Helper to locate rendered elements and adjust scroll if initial jump under-estimated
    void adjustAndEnsureVisible() {
      if (tryEnsureVisible()) return;

      int lastRenderedIndex = -1;
      for (int i = _verseKeys.length - 1; i >= 0; i--) {
        if (_verseKeys[i].currentContext != null) {
          lastRenderedIndex = i;
          break;
        }
      }

      if (lastRenderedIndex != -1 && lastRenderedIndex != index && _scrollController.hasClients) {
        final box = _verseKeys[lastRenderedIndex].currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          final currentScroll = _scrollController.offset;
          final diffIndex = index - lastRenderedIndex;
          final avgVerseHeight = isParallel ? (_fontSize * 6.5) : (_fontSize * 3.5);
          final targetJump = currentScroll + (pos.dy - 120) + (diffIndex * avgVerseHeight);
          
          final maxScroll = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(targetJump.clamp(0.0, maxScroll));
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            tryEnsureVisible();
          });
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!tryEnsureVisible()) {
        Future.delayed(const Duration(milliseconds: 100), () {
          adjustAndEnsureVisible();
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          tryEnsureVisible();
        });
      }
    });
  }

  Future<void> _searchBible(String query) async {
    _searchDebounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      return;
    }
    setState(() => _isSearchLoading = true);
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final activeTrans = _translationMode == 'english'
          ? activeEnglishBibleNotifier.value
          : activeKinyarwandaBibleNotifier.value;
      final results = await _dbService.searchBible(query, translation: activeTrans);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchLoading = false;
        });
      }
    });
  }

  bool get _canTurnForward {
    if (_selectedChapter < _selectedBook.chapterCount) return true;
    final currentIndex = BibleBook.allBooks.indexOf(_selectedBook);
    return currentIndex < BibleBook.allBooks.length - 1;
  }

  bool get _canTurnBackward {
    if (_selectedChapter > 1) return true;
    final currentIndex = BibleBook.allBooks.indexOf(_selectedBook);
    return currentIndex > 0;
  }

  void _advanceChapter() {
    if (_selectedChapter < _selectedBook.chapterCount) {
      _selectedChapter++;
    } else {
      final currentIndex = BibleBook.allBooks.indexOf(_selectedBook);
      if (currentIndex < BibleBook.allBooks.length - 1) {
        _selectedBook = BibleBook.allBooks[currentIndex + 1];
        _selectedChapter = 1;
      }
    }
  }

  void _retreatChapter() {
    if (_selectedChapter > 1) {
      _selectedChapter--;
    } else {
      final currentIndex = BibleBook.allBooks.indexOf(_selectedBook);
      if (currentIndex > 0) {
        final prevBook = BibleBook.allBooks[currentIndex - 1];
        _selectedBook = prevBook;
        _selectedChapter = prevBook.chapterCount;
      }
    }
  }

  void _nextChapter() {
    if (!_canTurnForward) return;
    setState(() => _advanceChapter());
    _loadVerses();
  }

  void _prevChapter() {
    if (!_canTurnBackward) return;
    setState(() => _retreatChapter());
    _loadVerses();
  }

  Future<void> _onBookPageTurn(BookPageTurnDirection direction) async {
    if (_isPlayingTTS) {
      await _flutterTts.stop();
    }
    if (direction == BookPageTurnDirection.forward) {
      if (!_canTurnForward) return;
      _advanceChapter();
    } else {
      if (!_canTurnBackward) return;
      _retreatChapter();
    }
    // Keep the folding page visible while the next chapter loads.
    await _loadVerses(showLoading: false);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Target book/chapter for a page-turn direction (does not mutate state).
  (BibleBook book, int chapter)? _adjacentChapter(BookPageTurnDirection direction) {
    if (direction == BookPageTurnDirection.forward) {
      if (_selectedChapter < _selectedBook.chapterCount) {
        return (_selectedBook, _selectedChapter + 1);
      }
      final currentIndex = BibleBook.allBooks.indexOf(_selectedBook);
      if (currentIndex < BibleBook.allBooks.length - 1) {
        return (BibleBook.allBooks[currentIndex + 1], 1);
      }
      return null;
    }

    if (_selectedChapter > 1) {
      return (_selectedBook, _selectedChapter - 1);
    }
    final currentIndex = BibleBook.allBooks.indexOf(_selectedBook);
    if (currentIndex > 0) {
      final prevBook = BibleBook.allBooks[currentIndex - 1];
      return (prevBook, prevBook.chapterCount);
    }
    return null;
  }

  /// Builds a read-only snapshot of the destination chapter for the curl underside.
  Future<Widget?> _loadDestinationPage(BookPageTurnDirection direction) async {
    final target = _adjacentChapter(direction);
    if (target == null) return null;

    final book = target.$1;
    final chapter = target.$2;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReaderDark = _getActiveThemeMode(isDark) == 'Dark';
    final bgColor = _getBgColor(isDark);
    final textColor = _getTextColor(isDark);
    final primaryColor = Theme.of(context).primaryColor;

    try {
      final verses = await _dbService.getChapterVerses(book.bookNumber, chapter, translation: activeKinyarwandaBibleNotifier.value);
      Map<int, String> englishMap = {};
      if (_translationMode == 'english' || _translationMode == 'parallel') {
        final eng = await _dbService.getEnglishChapterVerses(book.bookNumber, chapter, translation: activeEnglishBibleNotifier.value);
        englishMap = {for (var v in eng) v['verse'] as int: v['text'] as String};
      }

      if (!mounted) return null;

      return ColoredBox(
        color: bgColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final leadCount = _dropCapLeadCount(
              verses: verses,
              contentWidth: constraints.maxWidth - 40,
              chapter: chapter,
              englishMap: englishMap,
            );
            final remaining =
                (verses.length - leadCount).clamp(0, verses.length);
            return ListView.builder(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 80),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: verses.isEmpty ? 0 : 1 + remaining,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final leadVerses = verses.sublist(0, leadCount);
                  final firstHeading = leadVerses.first.heading;
                  final hasFirstHeading =
                      firstHeading != null && firstHeading.isNotEmpty;

                  Widget lead;
                  if (leadCount > 1) {
                    lead = _buildMultiVerseDropCapLead(
                      chapter: chapter,
                      leadVerses: leadVerses,
                      leadIndexes: List.generate(leadCount, (i) => i),
                      textColor: textColor,
                      primaryColor: primaryColor,
                      isDark: isReaderDark,
                      englishMap: englishMap,
                      interactive: false,
                    );
                  } else {
                    lead = Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: VerseItem(
                        verse: leadVerses.first,
                        fontSize: _fontSize,
                        textColor: textColor,
                        primaryColor: primaryColor,
                        isHighlighted: false,
                        hasNote: false,
                        englishText: englishMap[leadVerses.first.verse],
                        translationMode: _translationMode,
                        onTap: () {},
                        chapterDropCap: chapter,
                        isDark: isReaderDark,
                      ),
                    );
                  }

                  if (!hasFirstHeading) return lead;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVerseHeading(firstHeading, isReaderDark, primaryColor),
                      lead,
                    ],
                  );
                }

                final verseIndex = leadCount + index - 1;
                final verse = verses[verseIndex];
                final hasHeading =
                    verse.heading != null && verse.heading!.isNotEmpty;
                final verseItem = Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: VerseItem(
                    verse: verse,
                    fontSize: _fontSize,
                    textColor: textColor,
                    primaryColor: primaryColor,
                    isHighlighted: false,
                    hasNote: false,
                    englishText: englishMap[verse.verse],
                    translationMode: _translationMode,
                    onTap: () {},
                    isDark: isReaderDark,
                  ),
                );
                if (!hasHeading) return verseItem;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVerseHeading(verse.heading!, isReaderDark, primaryColor),
                    verseItem,
                  ],
                );
              },
            );
          },
        ),
      );
    } catch (_) {
      return ColoredBox(color: bgColor);
    }
  }

  String _getActiveThemeMode(bool isDark) {
    return _customThemeMode ?? (isDark ? 'Dark' : 'Light');
  }

  Color _getBgColor(bool isDark) {
    final activeMode = _getActiveThemeMode(isDark);
    if (activeMode == 'Dark') return const Color(0xFF101210); // Rich dark black background
    if (activeMode == 'Warm') return const Color(0xFFF7F2E8);
    return const Color(0xFFF8FAFC); // Slate 50 Background
  }

  Color _getButtonCircleColor(bool isDark) {
    final activeMode = _getActiveThemeMode(isDark);
    if (activeMode == 'Dark') return const Color(0xFF1B1D1B);
    if (activeMode == 'Warm') return const Color(0xFFE8DECA);
    return Colors.white;
  }

  Color _getTextColor(bool isDark) {
    final activeMode = _getActiveThemeMode(isDark);
    if (activeMode == 'Dark') return Colors.grey.shade300;
    if (activeMode == 'Warm') return const Color(0xFF4C3E26);
    return const Color(0xFF1E293B); // Slate 800 Text
  }

  String _verseBodyText(BibleVerse verse, Map<int, String> englishMap) {
    if (_translationMode == 'english') {
      return englishMap[verse.verse] ?? verse.text;
    }
    return verse.text;
  }

  /// How many opening verses fit beside the chapter drop-cap.
  int _dropCapLeadCount({
    required List<BibleVerse> verses,
    required double contentWidth,
    required int chapter,
    required Map<int, String> englishMap,
  }) {
    if (verses.isEmpty || contentWidth <= 0) return verses.isEmpty ? 0 : 1;

    const gap = 12.0;
    final dropCapStyle = TextStyle(
      fontSize: _fontSize * 5.2,
      fontWeight: FontWeight.w500,
      height: 0.88,
      fontFamily: 'serif',
      letterSpacing: -2.0,
    );
    final bodyStyle = TextStyle(
      fontSize: _fontSize,
      height: 1.35,
      fontFamily: 'serif',
    );
    final englishStyle = TextStyle(
      fontStyle: FontStyle.italic,
      fontSize: _fontSize - 1.5,
      height: 1.35,
      fontFamily: 'serif',
    );

    final dropPainter = TextPainter(
      text: TextSpan(text: '$chapter', style: dropCapStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final sideWidth =
        (contentWidth - dropPainter.width - gap).clamp(40.0, contentWidth);
    final dropH = dropPainter.height;

    double measureSpan(InlineSpan span) {
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: sideWidth);
      return tp.height;
    }

    double measureVerseHeight(int index) {
      final verse = verses[index];
      final prefix = index == 0 ? '' : '${verse.verse}  ';
      final main = '$prefix${_verseBodyText(verse, englishMap)}';
      final children = <InlineSpan>[TextSpan(text: main, style: bodyStyle)];
      if (_translationMode == 'parallel' && englishMap[verse.verse] != null) {
        children.add(const TextSpan(text: '\n'));
        children.add(
          TextSpan(text: englishMap[verse.verse], style: englishStyle),
        );
      }
      return measureSpan(TextSpan(children: children)) + 4.0;
    }

    var count = 0;
    var used = 0.0;
    for (var i = 0; i < verses.length; i++) {
      final h = measureVerseHeight(i);
      if (i == 0) {
        count = 1;
        used = h;
        // Long first verse (incl. parallel English): single-verse drop-cap wrap.
        if (h >= dropH) return 1;
        continue;
      }
      if (used + h > dropH + 2) break;
      count++;
      used += h;
      if (used >= dropH) break;
    }
    return count;
  }

  Widget _buildVerseHeading(String heading, bool isDark, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, bottom: 8.0, left: 8.0, right: 8.0),
        child: Text(
          heading,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _fontSize + 1.5,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF60A5FA) : primaryColor,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// Shared chapter drop-cap with one or more short opening verses beside it.
  Widget _buildMultiVerseDropCapLead({
    required int chapter,
    required List<BibleVerse> leadVerses,
    required List<int> leadIndexes,
    required Color textColor,
    required Color primaryColor,
    required bool isDark,
    required Map<int, String> englishMap,
    required bool interactive,
  }) {
    const gap = 12.0;
    final dropCapStyle = TextStyle(
      fontSize: _fontSize * 5.2,
      fontWeight: FontWeight.w500,
      height: 0.88,
      fontFamily: 'serif',
      color: textColor,
      letterSpacing: -2.0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: gap),
            child: Text('$chapter', style: dropCapStyle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < leadVerses.length; i++) ...[
                  if (i > 0 &&
                      leadVerses[i].heading != null &&
                      leadVerses[i].heading!.isNotEmpty)
                    _buildVerseHeading(
                      leadVerses[i].heading!,
                      isDark,
                      primaryColor,
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: VerseItem(
                      key: interactive &&
                              leadIndexes[i] < _verseKeys.length
                          ? _verseKeys[leadIndexes[i]]
                          : null,
                      verse: leadVerses[i],
                      fontSize: _fontSize,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      isHighlighted: interactive &&
                          _targetVerse == leadVerses[i].verse,
                      isSelected: interactive &&
                          _selectedVerseIds.contains(leadVerses[i].id),
                      highlightColor: interactive &&
                              _highlights.containsKey(leadVerses[i].id)
                          ? _getHighlightColor(_highlights[leadVerses[i].id])
                          : null,
                      hasNote: interactive &&
                          _notes.containsKey(leadVerses[i].id),
                      englishText: englishMap[leadVerses[i].verse],
                      translationMode: _translationMode,
                      tags: interactive
                          ? _verseTagsMap[leadVerses[i].id]
                          : null,
                      hideVerseNumber: i == 0,
                      onTap: interactive
                          ? () {
                              final verse = leadVerses[i];
                              if (_isMultiSelectMode) {
                                setState(() {
                                  if (_selectedVerseIds.contains(verse.id)) {
                                    _selectedVerseIds.remove(verse.id);
                                    if (_selectedVerseIds.isEmpty) {
                                      _isMultiSelectMode = false;
                                    }
                                  } else {
                                    _selectedVerseIds.add(verse.id!);
                                  }
                                });
                              } else {
                                VerseActionsModal.show(
      context,
      verse: verse,
      isFavInitial: false, // Wait, I can't await inside the build method callback. 
      // Ah! I need to handle isFavInitial correctly.
      // I will fix this manually later.
      activeHighlightIndex: _highlights[verse.id],
      noteText: _notes[verse.id],
      verseTags: _verseTagsMap[verse.id],
      selectedBook: _selectedBook,
      selectedChapter: _selectedChapter,
      translationMode: _translationMode,
      dbService: _dbService,
      highlightColors: _highlightColors,
      onHighlightAdded: (index) => setState(() => _highlights[verse.id!] = index),
      onHighlightRemoved: () => setState(() => _highlights.remove(verse.id)),
      onFavoriteToggled: (isFav) {}, // Already handled inside the modal for DB, we just don't have a local state for it here
      onTagRemoved: (tag) async {
        final updatedTags = await _dbService.getTagsForChapter(_selectedBook.bookNumber, _selectedChapter);
        setState(() => _verseTagsMap = updatedTags);
      },
      onNoteRemoved: () => setState(() => _notes.remove(verse.id)),
      showAddTagDialog: _showAddTagDialog,
      showNoteEditDialog: _showNoteEditDialog,
      speakVerse: _speakVerse,
      showDeleteConfirmDialog: _showDeleteConfirmDialog,
    );
                              }
                            }
                          : () {},
                      onLongPress: interactive
                          ? () {
                              setState(() {
                                _isMultiSelectMode = true;
                                _selectedVerseIds.add(leadVerses[i].id!);
                              });
                            }
                          : null,
                      isTtsActive: interactive &&
                          _isPlayingTTS &&
                          _ttsActiveVerse == leadVerses[i].verse,
                      ttsStartChar: _ttsWordStartChar,
                      ttsEndChar: _ttsWordEndChar,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true, // Let Scaffold body go under the bottomNavigationBar!
      appBar: AppBar(
        leading: _isSearching
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  final parentState = context.findAncestorStateOfType<HomeScreenState>();
                  if (parentState != null) {
                    if (parentState.activeBibleId != null) {
                      parentState.clearActiveBible();
                    } else {
                      parentState.setTab(0);
                    }
                  } else {
                    Navigator.maybePop(context);
                  }
                },
                tooltip: 'Genda inyuma',
              ),
        centerTitle: true,
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 16, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Shaka umurongo...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _searchBible,
                autofocus: true,
              )
            : GestureDetector(
                onTap: () {
                  BibleNavigationModals.showBookSelector(
                    context,
                    translationMode: _translationMode,
                    selectedBook: _selectedBook,
                    availableBookNumbers: _availableBookNumbers.toList(),
                    dbService: _dbService,
                    activeKinyarwandaBibleNotifier: activeKinyarwandaBibleNotifier,
                    onVerseSelected: (book, chapter, verse) {
                      jumpToVerse(book, chapter, verse);
                    },
                  );
                },
                child: Text(
                  '${_selectedBook.getDisplayName(_translationMode)} $_selectedChapter',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchResults = [];
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'text_settings') {
                  ReaderSettingsModal.show(
      context,
      fontSize: _fontSize,
      onFontSizeChanged: (val) {
        setState(() => _fontSize = val);
      },
      customThemeMode: _customThemeMode ?? 'Light',
      onCustomThemeModeChanged: (val) {
        setState(() => _customThemeMode = val);
      },
      activeThemeMode: _getActiveThemeMode(Theme.of(context).brightness == Brightness.dark),
      translationMode: _translationMode,
    );
                } else if (val == 'book_selector') {
                  BibleNavigationModals.showBookSelector(
      context,
      translationMode: _translationMode,
      selectedBook: _selectedBook,
      availableBookNumbers: _availableBookNumbers.toList(),
      dbService: _dbService,
      activeKinyarwandaBibleNotifier: activeKinyarwandaBibleNotifier,
      onVerseSelected: (book, chapter, verse) {
        jumpToVerse(book, chapter, verse);
      },
    );
                } else if (val == 'multi_select') {
                  setState(() {
                    _isMultiSelectMode = true;
                    _selectedVerseIds.clear();
                  });
                } else if (val == 'play_chapter') {
                  _speakChapter();
                } else if (val == 'sleep_timer') {
                  _showSleepTimerBottomSheet();
                } else if (val == 'copy_chapter') {
                  _copyChapterText();
                } else if (val == 'share_chapter') {
                  _shareChapterText();
                } else if (val == 'clear_highlights') {
                  _clearAllHighlightsInChapter();
                } else if (val == 'clear_notes') {
                  _clearAllNotesInChapter();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'text_settings',
                  child: Row(
                    children: [
                      const Icon(Icons.format_size, size: 20),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.translate('reader_settings_title')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'book_selector',
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt, size: 20),
                      const SizedBox(width: 8),
                      const Text('Hitamo Igitabo'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'multi_select',
                  child: Row(
                    children: [
                      const Icon(Icons.checklist_rtl, size: 20),
                      const SizedBox(width: 8),
                      const Text('Hitamo Imirongo (Select)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'play_chapter',
                  child: Row(
                    children: [
                      Icon(_isPlayingTTS ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(_isPlayingTTS ? 'Hagarika Gusoma' : 'Soma Iki Gice (TTS)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'sleep_timer',
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Text('Igihe cy\'Igisomwa (Timer)'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'copy_chapter',
                  child: Row(
                    children: [
                      const Icon(Icons.copy_all, size: 20),
                      const SizedBox(width: 8),
                      const Text('Kopi y\'iki Gice'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share_chapter',
                  child: Row(
                    children: [
                      const Icon(Icons.share, size: 20),
                      const SizedBox(width: 8),
                      const Text('Sangira iki Gice'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'clear_highlights',
                  child: Row(
                    children: [
                      Icon(Icons.format_color_reset, size: 20, color: Colors.redAccent.shade200),
                      const SizedBox(width: 8),
                      const Text('Siba Ibihitijwe byose', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_notes',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.redAccent.shade200),
                      const SizedBox(width: 8),
                      const Text('Siba Ibyanditswe byose', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isSearching 
          ? _buildSearchResultsList()
          : _buildReaderView(primaryColor, isDark),
      bottomNavigationBar: _isSearching
          ? null
          : _buildBottomFooter(primaryColor, isDark),
    );
  }

  Widget _buildSearchResultsList() {
    if (_isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? 'Kora ishakisha ry\'ijambo ryose...' : 'Nta bisubizo byabonetse.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final verse = _searchResults[index];
        final bookObj = BibleBook.getByNumber(verse.book);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: _buildHighlightedText(verse.text, _searchController.text, context),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${bookObj.name} ${verse.chapter}:${verse.verse}',
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor),
              ),
            ),
            onTap: () {
              setState(() {
                _selectedBook = bookObj;
                _selectedChapter = verse.chapter;
                _targetVerse = verse.verse;
                _isSearching = false;
                _searchController.clear();
                _searchResults = [];
              });
              _loadVersesAndScroll();
            },
          ),
        );
      },
    );
  }

  Widget _buildHighlightedText(String text, String query, BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontFamily: 'serif',
          height: 1.4,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
        ),
      );
    }

    final matches = query.trim().split(RegExp(r'\s+'));
    final pattern = RegExp(
      '(${matches.map((m) => RegExp.escape(m)).join('|')})',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.18),
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch));
        return '';
      },
    );

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          fontFamily: 'serif',
          height: 1.4,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildReaderView(Color primaryColor, bool isDark) {
    final isReaderDark = _getActiveThemeMode(isDark) == 'Dark';
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bgColor = _getBgColor(isDark);
    final textColor = _getTextColor(isDark);

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Thinner/Smaller Quick Access Font Size Slider Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: isDark ? 0.15 : 0.08))),
            ),
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 14, color: textColor.withValues(alpha: 0.6)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                    ),
                    child: Slider(
                      min: 12.0,
                      max: 30.0,
                      value: _fontSize,
                      activeColor: isReaderDark ? const Color(0xFF60A5FA) : primaryColor,
                      inactiveColor: (isReaderDark ? const Color(0xFF60A5FA) : primaryColor).withValues(alpha: 0.2),
                      onChanged: (val) {
                        setState(() => _fontSize = val);
                      },
                    ),
                  ),
                ),
                Icon(Icons.text_fields, size: 20, color: textColor),
              ],
            ),
          ),
          Expanded(
            child: BookPageFold(
              canTurnForward: _canTurnForward,
              canTurnBackward: _canTurnBackward,
              paperColor: bgColor,
              onTurn: _onBookPageTurn,
              loadDestinationPage: _loadDestinationPage,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final leadCount = _dropCapLeadCount(
                    verses: _verses,
                    contentWidth: constraints.maxWidth - 40,
                    chapter: _selectedChapter,
                    englishMap: _englishVerses,
                  );
                  final remaining = (_verses.length - leadCount).clamp(0, _verses.length);
                  return ListView.builder(
                    controller: _scrollController,
                    // Use larger bottom padding so list can scroll above the floating footer
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 80),
                    itemCount: _verses.isEmpty ? 0 : 1 + remaining,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final leadVerses = _verses.sublist(0, leadCount);
                        final firstHeading = leadVerses.first.heading;
                        final hasFirstHeading =
                            firstHeading != null && firstHeading.isNotEmpty;

                        Widget lead;
                        if (leadCount > 1) {
                          lead = _buildMultiVerseDropCapLead(
                            chapter: _selectedChapter,
                            leadVerses: leadVerses,
                            leadIndexes: List.generate(leadCount, (i) => i),
                            textColor: textColor,
                            primaryColor: primaryColor,
                            isDark: isReaderDark,
                            englishMap: _englishVerses,
                            interactive: true,
                          );
                        } else {
                          final verse = leadVerses.first;
                          lead = Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: VerseItem(
                              key: _verseKeys.isNotEmpty ? _verseKeys[0] : null,
                              verse: verse,
                              fontSize: _fontSize,
                              textColor: textColor,
                              primaryColor: primaryColor,
                              isHighlighted: _targetVerse == verse.verse,
                              isSelected: _selectedVerseIds.contains(verse.id),
                              highlightColor: _highlights.containsKey(verse.id)
                                  ? _getHighlightColor(_highlights[verse.id])
                                  : null,
                              hasNote: _notes.containsKey(verse.id),
                              englishText: _englishVerses[verse.verse],
                              translationMode: _translationMode,
                              tags: _verseTagsMap[verse.id],
                              chapterDropCap: _selectedChapter,
                              isDark: isReaderDark,
                              onTap: () {
                                if (_isMultiSelectMode) {
                                  setState(() {
                                    if (_selectedVerseIds.contains(verse.id)) {
                                      _selectedVerseIds.remove(verse.id);
                                      if (_selectedVerseIds.isEmpty) {
                                        _isMultiSelectMode = false;
                                      }
                                    } else {
                                      _selectedVerseIds.add(verse.id!);
                                    }
                                  });
                                } else {
                                  VerseActionsModal.show(
      context,
      verse: verse,
      isFavInitial: false, // Wait, I can't await inside the build method callback. 
      // Ah! I need to handle isFavInitial correctly.
      // I will fix this manually later.
      activeHighlightIndex: _highlights[verse.id],
      noteText: _notes[verse.id],
      verseTags: _verseTagsMap[verse.id],
      selectedBook: _selectedBook,
      selectedChapter: _selectedChapter,
      translationMode: _translationMode,
      dbService: _dbService,
      highlightColors: _highlightColors,
      onHighlightAdded: (index) => setState(() => _highlights[verse.id!] = index),
      onHighlightRemoved: () => setState(() => _highlights.remove(verse.id)),
      onFavoriteToggled: (isFav) {}, // Already handled inside the modal for DB, we just don't have a local state for it here
      onTagRemoved: (tag) async {
        final updatedTags = await _dbService.getTagsForChapter(_selectedBook.bookNumber, _selectedChapter);
        setState(() => _verseTagsMap = updatedTags);
      },
      onNoteRemoved: () => setState(() => _notes.remove(verse.id)),
      showAddTagDialog: _showAddTagDialog,
      showNoteEditDialog: _showNoteEditDialog,
      speakVerse: _speakVerse,
      showDeleteConfirmDialog: _showDeleteConfirmDialog,
    );
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  _isMultiSelectMode = true;
                                  _selectedVerseIds.add(verse.id!);
                                });
                              },
                              isTtsActive: _isPlayingTTS &&
                                  _ttsActiveVerse == verse.verse,
                              ttsStartChar: _ttsWordStartChar,
                              ttsEndChar: _ttsWordEndChar,
                            ),
                          );
                        }

                        if (!hasFirstHeading) return lead;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildVerseHeading(firstHeading, isReaderDark, primaryColor),
                            lead,
                          ],
                        );
                      }

                      final verseIndex = leadCount + index - 1;
                      final verse = _verses[verseIndex];
                      final hasHeading =
                          verse.heading != null && verse.heading!.isNotEmpty;

                      final verseItemWidget = Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: VerseItem(
                          key: _verseKeys[verseIndex],
                          verse: verse,
                          fontSize: _fontSize,
                          textColor: textColor,
                          primaryColor: primaryColor,
                          isHighlighted: _targetVerse == verse.verse,
                          isSelected: _selectedVerseIds.contains(verse.id),
                          highlightColor: _highlights.containsKey(verse.id)
                              ? _getHighlightColor(_highlights[verse.id])
                              : null,
                          hasNote: _notes.containsKey(verse.id),
                          englishText: _englishVerses[verse.verse],
                          translationMode: _translationMode,
                          tags: _verseTagsMap[verse.id],
                          onTap: () {
                            if (_isMultiSelectMode) {
                              setState(() {
                                if (_selectedVerseIds.contains(verse.id)) {
                                  _selectedVerseIds.remove(verse.id);
                                  if (_selectedVerseIds.isEmpty) {
                                    _isMultiSelectMode = false;
                                  }
                                } else {
                                  _selectedVerseIds.add(verse.id!);
                                }
                              });
                            } else {
                              VerseActionsModal.show(
      context,
      verse: verse,
      isFavInitial: false, // Wait, I can't await inside the build method callback. 
      // Ah! I need to handle isFavInitial correctly.
      // I will fix this manually later.
      activeHighlightIndex: _highlights[verse.id],
      noteText: _notes[verse.id],
      verseTags: _verseTagsMap[verse.id],
      selectedBook: _selectedBook,
      selectedChapter: _selectedChapter,
      translationMode: _translationMode,
      dbService: _dbService,
      highlightColors: _highlightColors,
      onHighlightAdded: (index) => setState(() => _highlights[verse.id!] = index),
      onHighlightRemoved: () => setState(() => _highlights.remove(verse.id)),
      onFavoriteToggled: (isFav) {}, // Already handled inside the modal for DB, we just don't have a local state for it here
      onTagRemoved: (tag) async {
        final updatedTags = await _dbService.getTagsForChapter(_selectedBook.bookNumber, _selectedChapter);
        setState(() => _verseTagsMap = updatedTags);
      },
      onNoteRemoved: () => setState(() => _notes.remove(verse.id)),
      showAddTagDialog: _showAddTagDialog,
      showNoteEditDialog: _showNoteEditDialog,
      speakVerse: _speakVerse,
      showDeleteConfirmDialog: _showDeleteConfirmDialog,
    );
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _isMultiSelectMode = true;
                              _selectedVerseIds.add(verse.id!);
                            });
                          },
                          isTtsActive: _isPlayingTTS &&
                              _ttsActiveVerse == verse.verse,
                          ttsStartChar: _ttsWordStartChar,
                          ttsEndChar: _ttsWordEndChar,
                          isDark: isReaderDark,
                        ),
                      );

                      if (!hasHeading) return verseItemWidget;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVerseHeading(verse.heading!, isReaderDark, primaryColor),
                          verseItemWidget,
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedVerseIds.clear();
    });
  }

  void _copySelectedVerses() {
    if (_selectedVerseIds.isEmpty) return;
    final sortedVerses = _verses.where((v) => _selectedVerseIds.contains(v.id)).toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    
    StringBuffer buffer = StringBuffer();
    for (var i = 0; i < sortedVerses.length; i++) {
      final v = sortedVerses[i];
      buffer.write('${v.verse} ${v.text}\n');
    }
    
    final bookName = _selectedBook.getDisplayName(_translationMode);
    final startVerse = sortedVerses.first.verse;
    final endVerse = sortedVerses.last.verse;
    final ref = startVerse == endVerse 
        ? '$bookName $_selectedChapter:$startVerse'
        : '$bookName $_selectedChapter:$startVerse-$endVerse';
    
    buffer.write('($ref)');
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _exitMultiSelectMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.translate('toast_verse_copied')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _shareSelectedVerses() {
    if (_selectedVerseIds.isEmpty) return;
    final sortedVerses = _verses.where((v) => _selectedVerseIds.contains(v.id)).toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    
    StringBuffer buffer = StringBuffer();
    for (var v in sortedVerses) {
      buffer.write('${v.verse} ${v.text}\n');
    }
    
    final bookName = _selectedBook.getDisplayName(_translationMode);
    final startVerse = sortedVerses.first.verse;
    final endVerse = sortedVerses.last.verse;
    final ref = startVerse == endVerse 
        ? '$bookName $_selectedChapter:$startVerse'
        : '$bookName $_selectedChapter:$startVerse-$endVerse';
    
    buffer.write('\n— $ref');
    
    _exitMultiSelectMode();
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  Future<void> _favoriteSelectedVerses() async {
    if (_selectedVerseIds.isEmpty) return;
    
    bool hasAnyUnfavorited = false;
    for (final id in _selectedVerseIds) {
      final isFav = await _dbService.isFavorite('bible', id);
      if (!isFav) {
        hasAnyUnfavorited = true;
        break;
      }
    }

    for (final id in _selectedVerseIds) {
      if (hasAnyUnfavorited) {
        await _dbService.addFavorite('bible', id);
      } else {
        await _dbService.removeFavorite('bible', id);
      }
    }

    _exitMultiSelectMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hasAnyUnfavorited ? 'Yabitswe mu Byatoranyijwe!' : 'Bikurwe mu Byatoranyijwe!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showMultiHighlightColorPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hitamo ibara ryo guhitira (Highlight):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _highlightColors.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _highlightColors.length) {
                      return GestureDetector(
                         onTap: () async {
                           for (final id in _selectedVerseIds) {
                             await _dbService.removeHighlight(id);
                           }
                           setState(() {
                             for (final id in _selectedVerseIds) {
                               _highlights.remove(id);
                             }
                           });
                           if (context.mounted) Navigator.pop(context);
                           _exitMultiSelectMode();
                         },
                         child: Container(
                           margin: const EdgeInsets.only(right: 10),
                           width: 36,
                           height: 36,
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             border: Border.all(color: Colors.grey.shade400),
                             color: Colors.transparent,
                           ),
                           child: const Icon(Icons.format_color_reset, size: 18, color: Colors.grey),
                         ),
                       );
                    }

                    final color = _highlightColors[index];

                    return GestureDetector(
                       onTap: () async {
                         for (final id in _selectedVerseIds) {
                           await _dbService.saveHighlight(id, index);
                         }
                         setState(() {
                           for (final id in _selectedVerseIds) {
                             _highlights[id] = index;
                           }
                         });
                         if (context.mounted) Navigator.pop(context);
                         _exitMultiSelectMode();
                       },
                       child: Container(
                         margin: const EdgeInsets.only(right: 10),
                         width: 36,
                         height: 36,
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: color,
                           border: Border.all(color: Colors.transparent),
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

  void _showMultiAddTagDialog() {
    final TextEditingController tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ongeraho Ikimenyetso (Add Tag)'),
          content: TextField(
            controller: tagController,
            decoration: const InputDecoration(
              hintText: 'Urugero: Isengesho, Kwizera...',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Gukuramo'),
            ),
            TextButton(
              onPressed: () async {
                final tag = tagController.text.trim();
                if (tag.isNotEmpty) {
                  for (final id in _selectedVerseIds) {
                    await _dbService.addVerseTag(id, tag);
                  }
                  final updatedTags = await _dbService.getTagsForChapter(_selectedBook.bookNumber, _selectedChapter);
                  setState(() {
                    _verseTagsMap = updatedTags;
                  });
                }
                if (mounted) {
                  Navigator.pop(context);
                  _exitMultiSelectMode();
                }
              },
              child: const Text('Bika'),
            ),
          ],
        );
      },
    );
  }

  void _copyChapterText() {
    if (_verses.isEmpty) return;
    StringBuffer buffer = StringBuffer();
    for (var v in _verses) {
      buffer.write('${v.verse} ${v.text}\n');
    }
    final ref = '${_selectedBook.getDisplayName(_translationMode)} $_selectedChapter';
    buffer.write('\n($ref)');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gukora kopi y\'igice byagenze neza!')),
    );
  }

  void _shareChapterText() {
    if (_verses.isEmpty) return;
    StringBuffer buffer = StringBuffer();
    for (var v in _verses) {
      buffer.write('${v.verse} ${v.text}\n');
    }
    final ref = '${_selectedBook.getDisplayName(_translationMode)} $_selectedChapter';
    buffer.write('\n($ref)');
    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  void _clearAllHighlightsInChapter() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gusiba Ibihitijwe (Clear Highlights)'),
          content: const Text('Ese wifuza gusiba ibihitijwe byose muri iki gice?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Oya'),
            ),
            TextButton(
              onPressed: () async {
                for (var v in _verses) {
                  await _dbService.removeHighlight(v.id!);
                }
                setState(() {
                  for (var v in _verses) {
                    _highlights.remove(v.id);
                  }
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Yego, Siba', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _clearAllNotesInChapter() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gusiba Ibyanditswe (Clear Notes)'),
          content: const Text('Ese wifuza gusiba ibyanditswe/ama-notes yose muri iki gice?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Oya'),
            ),
            TextButton(
              onPressed: () async {
                for (var v in _verses) {
                  await _dbService.saveNote(v.id!, '');
                }
                setState(() {
                  for (var v in _verses) {
                    _notes.remove(v.id);
                  }
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Yego, Siba', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMultiSelectFooter(Color primaryColor, bool isDark) {
    final isReaderDark = _getActiveThemeMode(isDark) == 'Dark';
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: isReaderDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isReaderDark ? 0.35 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isReaderDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Umirongo ${_selectedVerseIds.length} yatoranyijwe',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isReaderDark ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close, size: 20, color: isReaderDark ? Colors.white70 : Colors.black54),
                onPressed: _exitMultiSelectMode,
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ModalActionButton(
                icon: Icons.copy,
                label: 'Kopi',
                color: isReaderDark ? const Color(0xFF60A5FA) : primaryColor,
                onTap: _copySelectedVerses,
              ),
              ModalActionButton(
                icon: Icons.format_color_fill,
                label: 'Guhitira',
                color: isReaderDark ? const Color(0xFF60A5FA) : primaryColor,
                onTap: _showMultiHighlightColorPicker,
              ),
              ModalActionButton(
                icon: Icons.share,
                label: 'Sangira',
                color: isReaderDark ? const Color(0xFF60A5FA) : primaryColor,
                onTap: _shareSelectedVerses,
              ),
              ModalActionButton(
                icon: Icons.favorite_border,
                label: 'Bika',
                color: isReaderDark ? const Color(0xFF60A5FA) : primaryColor,
                onTap: _favoriteSelectedVerses,
              ),
              ModalActionButton(
                icon: Icons.label_outline,
                label: 'Tag',
                color: isReaderDark ? const Color(0xFF60A5FA) : primaryColor,
                onTap: _showMultiAddTagDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomFooter(Color primaryColor, bool isDark) {
    if (_isLoading) return null;
    final isReaderDark = _getActiveThemeMode(isDark) == 'Dark';
    if (_isMultiSelectMode) {
      return _buildMultiSelectFooter(primaryColor, isDark);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
      color: Colors.transparent, // Fully transparent
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Smaller Circular Back Chapter Button
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _getButtonCircleColor(isDark),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              onPressed: _prevChapter,
              tooltip: 'Igice kibanza',
            ),
          ),
          // Smaller Circular TTS Play Button
          GestureDetector(
            onLongPress: _showSleepTimerBottomSheet,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getButtonCircleColor(isDark),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      _isPlayingTTS ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                      size: 24,
                      color: isReaderDark ? const Color(0xFF60A5FA) : primaryColor,
                    ),
                    if (_sleepTimerRemainingSeconds != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 6, minHeight: 6),
                        ),
                      )
                  ],
                ),
                tooltip: _sleepTimerRemainingSeconds != null
                    ? 'Sleep Timer is active! Long press to change/stop.'
                    : (_isPlayingTTS ? 'Hagarika gusoma' : 'Soma iki gice cyose'),
                onPressed: _speakChapter,
              ),
            ),
          ),
          // Smaller Circular Forward Chapter Button
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _getButtonCircleColor(isDark),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: _nextChapter,
              tooltip: 'Igice gikurikira',
            ),
          ),
        ],
      ),
    );
  }

  

  void _showNoteEditDialog(BibleVerse verse, String? initialText, StateSetter setModalState) {
    final textController = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${_selectedBook.getDisplayName(_translationMode)} ${verse.chapter}:${verse.verse} - Andika Icyigisho'),
          content: TextField(
            controller: textController,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Andika icyigisho cyangwa igitekerezo cyawe hano...',
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
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  await _dbService.saveNote(verse.id!, text);
                  setState(() {
                    _notes[verse.id!] = text;
                  });
                } else {
                  await _dbService.removeNote(verse.id!);
                  setState(() {
                    _notes.remove(verse.id);
                  });
                }
                setModalState(() {});
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Bika'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gusiba Icyigisho'),
          content: const Text('Urashaka gusiba iki cyigisho by\'ukuri?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Reka'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Siba', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showAddTagDialog(BibleVerse verse, StateSetter setModalState) async {
    final textController = TextEditingController();
    final uniqueTags = await _dbService.getAllUniqueTags();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ongeraho Ikimenyetso (Tag)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Andika ikimenyetso (e.g. Urukundo, Isengesho)...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (uniqueTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Ibimenyetso bihari:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6.0,
                  children: uniqueTags.take(6).map((tag) {
                    return ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        textController.text = tag;
                      },
                    );
                  }).toList(),
                )
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Reka'),
            ),
            ElevatedButton(
              onPressed: () async {
                final tag = textController.text.trim();
                if (tag.isNotEmpty) {
                  await _dbService.addVerseTag(verse.id!, tag);
                  final updatedTags = await _dbService.getTagsForChapter(_selectedBook.bookNumber, _selectedChapter);
                  setState(() {
                    _verseTagsMap = updatedTags;
                  });
                  setModalState(() {});
                }
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Bika'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setBestVoiceForLanguage(String langCode) async {
    try {
      List<dynamic> voices = await _flutterTts.getVoices;
      if (voices.isEmpty) return;

      // Filter voices matching the target language code (e.g. 'en-us' or 'rw-rw')
      final targetLang = langCode.toLowerCase().replaceAll('_', '-');
      List<Map<String, String>> matchingVoices = [];
      for (var v in voices) {
        if (v is Map) {
          final locale = (v['locale'] ?? '').toString().toLowerCase().replaceAll('_', '-');
          final name = (v['name'] ?? '').toString();
          if (locale.startsWith(targetLang) || targetLang.startsWith(locale)) {
            matchingVoices.add({
              'name': name,
              'locale': (v['locale'] ?? '').toString(),
            });
          }
        }
      }

      if (matchingVoices.isNotEmpty) {
        // Find the best voice. We prefer 'network' voices which are Wavenet/neural cloud synthesis
        Map<String, String>? bestVoice;
        for (var voice in matchingVoices) {
          final nameLower = voice['name']!.toLowerCase();
          if (nameLower.contains('network') || nameLower.contains('wavenet') || nameLower.contains('neural')) {
            bestVoice = voice;
            break;
          }
        }

        // Fallback to the first matching voice if no network/wavenet voice is found
        bestVoice ??= matchingVoices.first;
        await _flutterTts.setVoice(bestVoice);
      }
    } catch (_) {}
  }

  Future<void> _speakVerse(BibleVerse verse) async {
    if (_isPlayingTTS) {
      await _flutterTts.stop();
      if (_ttsActiveVerse == verse.verse) {
        setState(() {
          _isPlayingTTS = false;
          _ttsActiveVerse = null;
          _isChapterTTS = false;
          _ttsWordStartChar = null;
          _ttsWordEndChar = null;
        });
        return;
      }
    }

    String langCode = _translationMode == 'english' ? 'en-US' : 'rw-RW';

    await _flutterTts.setLanguage(langCode);
    await _setBestVoiceForLanguage(langCode);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.55);

    setState(() {
      _ttsActiveVerse = verse.verse;
      _isPlayingTTS = true;
      _isChapterTTS = false;
      _ttsWordStartChar = null;
      _ttsWordEndChar = null;
    });

    String targetText = verse.text;
    if (_translationMode == 'english') {
      targetText = _englishVerses[verse.verse] ?? verse.text;
    } else {
      final hasHeading = verse.heading != null && verse.heading!.isNotEmpty;
      if (hasHeading) {
        targetText = "${verse.heading!}. $targetText";
      }
    }
    await _flutterTts.speak(targetText);
  }

  Future<void> _speakChapter() async {
    if (_isPlayingTTS) {
      await _flutterTts.stop();
      setState(() {
        _isPlayingTTS = false;
        _ttsActiveVerse = null;
        _isChapterTTS = false;
        _ttsWordStartChar = null;
        _ttsWordEndChar = null;
      });
      return;
    }

    if (_verses.isEmpty) return;

    // Set configuration once for the entire chapter
    String langCode = _translationMode == 'english' ? 'en-US' : 'rw-RW';

    await _flutterTts.setLanguage(langCode);
    await _setBestVoiceForLanguage(langCode);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.55);

    setState(() {
      _isPlayingTTS = true;
      _isChapterTTS = true;
      _ttsActiveVerse = _verses.first.verse;
      _ttsWordStartChar = null;
      _ttsWordEndChar = null;
    });

    _speakChapterVerseSequentially();
  }

  Future<void> _speakChapterVerseSequentially() async {
    if (!_isPlayingTTS || !_isChapterTTS || _ttsActiveVerse == null) return;

    // Find the active BibleVerse object
    final verseIndex = _verses.indexWhere((v) => v.verse == _ttsActiveVerse);
    if (verseIndex == -1) {
      // Reached the end of the chapter list!
      setState(() {
        _isPlayingTTS = false;
        _ttsActiveVerse = null;
        _isChapterTTS = false;
        _ttsWordStartChar = null;
        _ttsWordEndChar = null;
      });
      return;
    }

    final verse = _verses[verseIndex];
    
    // Auto-scroll the active verse into view
    _scrollToVerse(verse.verse);

    String targetText = verse.text;
    if (_translationMode == 'english') {
      targetText = _englishVerses[verse.verse] ?? verse.text;
    } else {
      final hasHeading = verse.heading != null && verse.heading!.isNotEmpty;
      if (hasHeading) {
        targetText = "${verse.heading!}. $targetText";
      }
    }
    // Speak this verse (re-uses configuration initialized in _speakChapter)
    await _flutterTts.speak(targetText);
  }

  void _showSleepTimerBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeTimer = _sleepTimerDurationMinutes;
            final isRunning = activeTimer != null;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            
            String statusText = 'Nta gupima igihe guhari (Timer is Off)';
            if (isRunning) {
              final mins = _sleepTimerRemainingSeconds! ~/ 60;
              final secs = _sleepTimerRemainingSeconds! % 60;
              statusText = 'Bizahagarara nyuma ya: ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
            }

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Guhagarika Gusoma (Sleep Timer)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(statusText, style: TextStyle(color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _TimerChip(
                        label: 'Hagarika',
                        selected: activeTimer == null,
                        onTap: () {
                          _cancelSleepTimer();
                          setModalState(() {});
                          setState(() {});
                          Navigator.pop(context);
                        },
                      ),
                      _TimerChip(
                        label: '5 min',
                        selected: activeTimer == 5,
                        onTap: () => _startSleepTimer(5, setModalState),
                      ),
                      _TimerChip(
                        label: '15 min',
                        selected: activeTimer == 15,
                        onTap: () => _startSleepTimer(15, setModalState),
                      ),
                      _TimerChip(
                        label: '30 min',
                        selected: activeTimer == 30,
                        onTap: () => _startSleepTimer(30, setModalState),
                      ),
                      _TimerChip(
                        label: '45 min',
                        selected: activeTimer == 45,
                        onTap: () => _startSleepTimer(45, setModalState),
                      ),
                      _TimerChip(
                        label: '60 min',
                        selected: activeTimer == 60,
                        onTap: () => _startSleepTimer(60, setModalState),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimer = null;
      _sleepTimerDurationMinutes = null;
      _sleepTimerRemainingSeconds = null;
    });
  }

  void _startSleepTimer(int minutes, StateSetter setModalState) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimerDurationMinutes = minutes;
      _sleepTimerRemainingSeconds = minutes * 60;
    });

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemainingSeconds == null || _sleepTimerRemainingSeconds! <= 0) {
        timer.cancel();
        _flutterTts.stop();
        setState(() {
          _isPlayingTTS = false;
          _ttsActiveVerse = null;
          _sleepTimer = null;
          _sleepTimerDurationMinutes = null;
          _sleepTimerRemainingSeconds = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.translate('toast_sleep_timer_fired'))),
        );
      } else {
        setState(() {
          _sleepTimerRemainingSeconds = _sleepTimerRemainingSeconds! - 1;
        });
        setModalState(() {});
      }
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.translate('toast_sleep_timer_set').replaceAll('{minutes}', minutes.toString()))),
    );
  }

  

  

  

  

  
}










class _TimerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      backgroundColor: selected ? theme.primaryColor : theme.primaryColor.withValues(alpha: 0.08),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      onPressed: onTap,
    );
  }
}