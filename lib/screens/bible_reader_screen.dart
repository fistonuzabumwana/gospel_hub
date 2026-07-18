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
import 'home_screen.dart';

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

  // Settings
  double _fontSize = 17.0;
  String? _customThemeMode; // null means adaptive to system/global theme

  // Search Results
  final TextEditingController _searchController = TextEditingController();
  List<BibleVerse> _searchResults = [];
  bool _isSearchLoading = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initTts();

    // Set initial translation mode from global notifier
    _translationMode = bibleTranslationNotifier.value;
    bibleTranslationNotifier.addListener(_onTranslationChanged);

    _loadLastRead().then((_) {
      _loadVerses();
    });
  }

  void _onTranslationChanged() {
    if (mounted) {
      setState(() {
        _translationMode = bibleTranslationNotifier.value;
      });
      _loadVerses();
    }
  }

  Future<void> _saveLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_book_number', _selectedBook.bookNumber);
    await prefs.setInt('last_read_chapter', _selectedChapter);
  }

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBookNum = prefs.getInt('last_read_book_number');
    final savedChapter = prefs.getInt('last_read_chapter');
    if (savedBookNum != null && savedChapter != null) {
      final book = BibleBook.allBooks.firstWhere(
        (b) => b.bookNumber == savedBookNum,
        orElse: () => BibleBook.allBooks.first,
      );
      _selectedBook = book;
      _selectedChapter = savedChapter;
    }
  }

  @override
  void dispose() {
    bibleTranslationNotifier.removeListener(_onTranslationChanged);
    _scrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
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

  Future<void> _loadVerses() async {
    setState(() => _isLoading = true);
    try {
      _saveLastRead();
      final verses = await _dbService.getChapterVerses(_selectedBook.bookNumber, _selectedChapter);
      final highlights = await _dbService.getHighlightsForChapter(_selectedBook.bookNumber, _selectedChapter);
      final notes = await _dbService.getNotesForChapter(_selectedBook.bookNumber, _selectedChapter);
      final tags = await _dbService.getTagsForChapter(_selectedBook.bookNumber, _selectedChapter);
      
      // Log reading history in background
      _dbService.logReading(_selectedBook.bookNumber, _selectedChapter);

      Map<int, String> englishVersesMap = {};
      if (_translationMode == 'english' || _translationMode == 'parallel') {
        final engVerses = await _dbService.getEnglishChapterVerses(_selectedBook.bookNumber, _selectedChapter);
        englishVersesMap = {for (var v in engVerses) v['verse'] as int: v['text'] as String};
      }

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(_targetVerse!);
        // Reset target verse after animation completes (approx 2.5s)
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
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

    // 1. Estimate scroll offset to jump close to the target
    double estimatedOffset = 0;
    for (int i = 0; i < index; i++) {
      final v = _verses[i];
      // Assume a conservative characters-per-line to avoid under-estimating height
      final charsPerLine = 34.0 * (17.0 / _fontSize);
      
      int lines = 0;
      if (_translationMode == 'parallel') {
        final rwTextLength = v.text.length;
        final engTextLength = (_englishVerses[v.verse] ?? '').length;
        // Each translation gets its own text span block divided by a newline
        lines = (rwTextLength / charsPerLine).ceil() + (engTextLength / charsPerLine).ceil() + 1;
      } else if (_translationMode == 'english') {
        final engTextLength = (_englishVerses[v.verse] ?? v.text).length;
        lines = (engTextLength / charsPerLine).ceil();
      } else {
        final rwTextLength = v.text.length;
        lines = (rwTextLength / charsPerLine).ceil();
      }
      
      final hasNote = _notes.containsKey(v.id);
      final tags = _verseTagsMap[v.id];
      final tagCount = tags != null ? tags.length : 0;
      final hasHeading = v.heading != null && v.heading!.isNotEmpty;
      
      double headingHeight = 0;
      if (hasHeading) {
        final headingTextLength = v.heading!.length;
        final headingLines = (headingTextLength / charsPerLine).ceil();
        headingHeight = headingLines * ((_fontSize + 1.5) * 1.4) + 28.0;
      }
      
      final verseHeight = lines * (_fontSize * 1.6) + 16.0 + (hasNote ? 12.0 : 0.0) + (tagCount > 0 ? 24.0 : 0.0) + headingHeight;
      estimatedOffset += verseHeight;
    }

    // 2. Jump close so ListView builds it
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(estimatedOffset);
    }

    // Helper to perform the precise animated scroll
    void doEnsureVisible() {
      if (index < _verseKeys.length) {
        final keyContext = _verseKeys[index].currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.2, // Align to top 20% of screen
          );
        }
      }
    }

    // 3. Try to scroll in the next frame. If context is not ready, wait a brief 100ms for ListView to render.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index < _verseKeys.length && _verseKeys[index].currentContext != null) {
        doEnsureVisible();
      } else {
        // Retry 1: after 100ms
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          if (index < _verseKeys.length && _verseKeys[index].currentContext != null) {
            doEnsureVisible();
          } else {
            // Retry 2: after another 200ms
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                doEnsureVisible();
              }
            });
          }
        });
      }
    });
  }

  Future<void> _searchBible(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearchLoading = true);
    final results = await _dbService.searchBible(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    }
  }

  void _nextChapter() {
    if (_selectedChapter < _selectedBook.chapterCount) {
      setState(() {
        _selectedChapter++;
      });
      _loadVerses();
    } else {
      // Go to next book
      final currentIndex = BibleBook.allBooks.indexOf(_selectedBook);
      if (currentIndex < BibleBook.allBooks.length - 1) {
        setState(() {
          _selectedBook = BibleBook.allBooks[currentIndex + 1];
          _selectedChapter = 1;
        });
        _loadVerses();
      }
    }
  }

  void _prevChapter() {
    if (_selectedChapter > 1) {
      setState(() {
        _selectedChapter--;
      });
      _loadVerses();
    } else {
      // Go to prev book
      final currentIndex = BibleBook.allBooks.indexOf(_selectedBook);
      if (currentIndex > 0) {
        final prevBook = BibleBook.allBooks[currentIndex - 1];
        setState(() {
          _selectedBook = prevBook;
          _selectedChapter = prevBook.chapterCount;
        });
        _loadVerses();
      }
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
                    parentState.setTab(0);
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
                onTap: _showBookSelectorModal,
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
                  _showSettingsBottomSheet();
                } else if (val == 'book_selector') {
                  _showBookSelectorModal();
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
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: _buildHighlightedText(verse.text, _searchController.text, context),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '${bookObj.name} ${verse.chapter}:${verse.verse}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
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
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.18),
              color: Theme.of(context).primaryColor,
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
                      activeColor: primaryColor,
                      inactiveColor: primaryColor.withValues(alpha: 0.2),
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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -200) {
                  _nextChapter();
                } else if (velocity > 200) {
                  _prevChapter();
                }
              },
              child: ListView.builder(
                controller: _scrollController,
                // Use larger bottom padding (e.g. 80.0) so list view can be scrolled fully above the floating footer
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 80),
                itemCount: _verses.length,
                itemBuilder: (context, index) {
                  final verse = _verses[index];
                  final hasHeading = verse.heading != null && verse.heading!.isNotEmpty;

                  final verseItemWidget = Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: VerseItem(
                      key: _verseKeys[index],
                      verse: verse,
                      fontSize: _fontSize,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      isHighlighted: _targetVerse == verse.verse,
                      isSelected: _selectedVerseIds.contains(verse.id),
                      highlightColor: _highlights.containsKey(verse.id)
                          ? _highlightColors[_highlights[verse.id]!]
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
                          _showVerseActionsModal(verse);
                        }
                      },
                      onLongPress: () {
                        setState(() {
                          _isMultiSelectMode = true;
                          _selectedVerseIds.add(verse.id!);
                        });
                      },
                      isTtsActive: _isPlayingTTS && _ttsActiveVerse == verse.verse,
                      ttsStartChar: _ttsWordStartChar,
                      ttsEndChar: _ttsWordEndChar,
                    ),
                  );

                  if (hasHeading) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20.0, bottom: 8.0, left: 8.0, right: 8.0),
                            child: Text(
                              verse.heading!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _fontSize + 1.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF60A5FA) : primaryColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        verseItemWidget,
                      ],
                    );
                  }

                  return verseItemWidget;
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
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 20),
                onPressed: _exitMultiSelectMode,
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionButton(
                icon: Icons.copy,
                label: 'Kopi',
                onTap: _copySelectedVerses,
              ),
              _ActionButton(
                icon: Icons.format_color_fill,
                label: 'Guhitira',
                onTap: _showMultiHighlightColorPicker,
              ),
              _ActionButton(
                icon: Icons.share,
                label: 'Sangira',
                onTap: _shareSelectedVerses,
              ),
              _ActionButton(
                icon: Icons.favorite_border,
                label: 'Bika',
                onTap: _favoriteSelectedVerses,
              ),
              _ActionButton(
                icon: Icons.label_outline,
                label: 'Tag',
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
                      color: primaryColor,
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

  void _showVerseActionsModal(BibleVerse verse) async {
    final isFavInitial = await _dbService.isFavorite('bible', verse.id!);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!mounted) return;

    bool localIsFav = isFavInitial;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeHighlightIndex = _highlights[verse.id];
            final noteText = _notes[verse.id];

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedBook.getDisplayName(_translationMode)} ${verse.chapter}:${verse.verse}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verse.text,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontFamily: 'serif',
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Highlight Colors Selector ──
                  const Text('Guhitira umurongo (Highlight):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _highlightColors.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _highlightColors.length) {
                          return GestureDetector(
                            onTap: () async {
                              await _dbService.removeHighlight(verse.id!);
                              setState(() {
                                _highlights.remove(verse.id);
                              });
                              setModalState(() {});
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
                        final isSelected = activeHighlightIndex == index;

                        return GestureDetector(
                          onTap: () async {
                            await _dbService.saveHighlight(verse.id!, index);
                            setState(() {
                              _highlights[verse.id!] = index;
                            });
                            setModalState(() {});
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                                width: isSelected ? 3.0 : 1.0,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Study Tags Section ──
                  const Text('Ibimenyetso (Tags):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...?_verseTagsMap[verse.id]?.map((tag) {
                        return Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 12),
                          onDeleted: () async {
                            await _dbService.removeVerseTag(verse.id!, tag);
                            final updatedTags = await _dbService.getTagsForChapter(_selectedBook.bookNumber, _selectedChapter);
                            setState(() {
                              _verseTagsMap = updatedTags;
                            });
                            setModalState(() {});
                          },
                        );
                      }),
                      ActionChip(
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        avatar: const Icon(Icons.add, size: 14),
                        label: const Text('Ongeraho', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _showAddTagDialog(verse, setModalState);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Actions Row ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ActionButton(
                          icon: localIsFav ? Icons.favorite : Icons.favorite_border,
                          label: localIsFav ? 'Kuraho' : 'Bika',
                          color: localIsFav ? Colors.red : null,
                          onTap: () async {
                            if (localIsFav) {
                              await _dbService.removeFavorite('bible', verse.id!);
                            } else {
                              await _dbService.addFavorite('bible', verse.id!);
                            }
                            setModalState(() {
                              localIsFav = !localIsFav;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(localIsFav ? 'Yabitswe mu Byatoranyijwe!' : 'Mukuraho!'),
                                duration: const Duration(seconds: 1),
                              )
                            );
                          },
                        ),
                        _ActionButton(
                          icon: Icons.copy,
                          label: 'Kopi',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: '${verse.text} (${_selectedBook.getDisplayName(_translationMode)} ${verse.chapter}:${verse.verse})'));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.translate('toast_verse_copied')), duration: const Duration(seconds: 1))
                            );
                          },
                        ),
                        _ActionButton(
                          icon: Icons.share,
                          label: 'Sangira',
                          onTap: () {
                            Navigator.pop(context);
                            SharePlus.instance.share(
                              ShareParams(
                                text: '${verse.text}\n\n— ${_selectedBook.getDisplayName(_translationMode)} ${verse.chapter}:${verse.verse}',
                              ),
                            );
                          },
                        ),
                        _ActionButton(
                          icon: Icons.edit_note,
                          label: 'Icyigisho',
                          onTap: () {
                            _showNoteEditDialog(verse, noteText, setModalState);
                          },
                        ),
                        _ActionButton(
                          icon: Icons.volume_up_outlined,
                          label: 'Soma',
                          onTap: () {
                            Navigator.pop(context);
                            _speakVerse(verse);
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Note Preview Area ──
                  if (noteText != null && noteText.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Icyigisho cyabitswe (Note):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0.5,
                      color: isDark ? const Color(0xFF1B1D1B) : const Color(0xFFF0F5FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              noteText,
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Hindura', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    _showNoteEditDialog(verse, noteText, setModalState);
                                  },
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  label: const Text('Siba', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  onPressed: () async {
                                    final confirm = await _showDeleteConfirmDialog();
                                    if (confirm == true) {
                                      await _dbService.removeNote(verse.id!);
                                      setState(() {
                                        _notes.remove(verse.id);
                                      });
                                      setModalState(() {});
                                    }
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
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
            final isRunning = _sleepTimerRemainingSeconds != null;
            
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
                  Text(statusText, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
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

  void _showSettingsBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.translate('reader_settings_font_size'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.text_fields, size: 16),
                      Expanded(
                        child: Slider(
                          min: 12.0,
                          max: 30.0,
                          value: _fontSize,
                          onChanged: (val) {
                            setModalState(() => _fontSize = val);
                            setState(() => _fontSize = val);
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 24),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(AppLocalizations.translate('reader_settings_theme'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ThemeButton(
                        label: AppLocalizations.translate('reader_settings_theme_white'),
                        selected: _getActiveThemeMode(isDark) == 'Light',
                        bgColor: Colors.white,
                        textColor: Colors.black87,
                        onTap: () {
                          setModalState(() => _customThemeMode = 'Light');
                          setState(() => _customThemeMode = 'Light');
                        },
                      ),
                      _ThemeButton(
                        label: AppLocalizations.translate('reader_settings_theme_warm'),
                        selected: _getActiveThemeMode(isDark) == 'Warm',
                        bgColor: const Color(0xFFF7F2E8),
                        textColor: const Color(0xFF4C3E26),
                        onTap: () {
                          setModalState(() => _customThemeMode = 'Warm');
                          setState(() => _customThemeMode = 'Warm');
                        },
                      ),
                      _ThemeButton(
                        label: AppLocalizations.translate('reader_settings_theme_black'),
                        selected: _getActiveThemeMode(isDark) == 'Dark',
                        bgColor: const Color(0xFF1B1D1B),
                        textColor: Colors.white70,
                        onTap: () {
                          setModalState(() => _customThemeMode = 'Dark');
                          setState(() => _customThemeMode = 'Dark');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(AppLocalizations.translate('reader_settings_translation'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                       _TranslationOptionButton(
                        label: 'Kinyarwanda',
                        selected: _translationMode == 'kinyarwanda',
                        onTap: () async {
                          bibleTranslationNotifier.value = 'kinyarwanda';
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('bible_translation_mode', 'kinyarwanda');
                          setModalState(() {});
                        },
                      ),
                      _TranslationOptionButton(
                        label: 'English KJV',
                        selected: _translationMode == 'english',
                        onTap: () async {
                          bibleTranslationNotifier.value = 'english';
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('bible_translation_mode', 'english');
                          setModalState(() {});
                        },
                      ),
                      _TranslationOptionButton(
                        label: 'Parallel',
                        selected: _translationMode == 'parallel',
                        onTap: () async {
                          bibleTranslationNotifier.value = 'parallel';
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('bible_translation_mode', 'parallel');
                          setModalState(() {});
                        },
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

  void _showBookSelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Theme.of(context).primaryColor,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: _translationMode == 'english' ? 'Old Testament' : 'Isezerano rya Kera'),
                      Tab(text: _translationMode == 'english' ? 'New Testament' : 'Isezerano Rishya'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookSelectorGrid(BibleBook.allBooks.where((b) => b.isOldTestament).toList(), scrollController),
                      _buildBookSelectorGrid(BibleBook.allBooks.where((b) => !b.isOldTestament).toList(), scrollController),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBookSelectorGrid(List<BibleBook> books, ScrollController controller) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final isSelected = book.bookNumber == _selectedBook.bookNumber;

        return Card(
          color: isSelected ? Theme.of(context).primaryColor : null,
          elevation: isSelected ? 4 : 1,
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
              _showChapterSelectorModal(book);
            },
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                book.getDisplayName(_translationMode),
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

  void _showChapterSelectorModal(BibleBook book) {
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
                        _showVerseSelectorModal(book, chapter);
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

  void _showVerseSelectorModal(BibleBook book, int chapter) async {
    // Temporarily fetch verses to get the exact count
    final verses = await _dbService.getChapterVerses(book.bookNumber, chapter);
    final verseCount = verses.length;
    
    if (!mounted) return;

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
                        jumpToVerse(book, chapter, verseNum);
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

class VerseItem extends StatefulWidget {
  final BibleVerse verse;
  final double fontSize;
  final Color textColor;
  final Color primaryColor;
  final bool isHighlighted;
  final Color? highlightColor;
  final bool hasNote;
  final String? englishText;
  final String translationMode;
  final List<String>? tags;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isTtsActive;
  final int? ttsStartChar;
  final int? ttsEndChar;
  final bool isSelected;

  const VerseItem({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.textColor,
    required this.primaryColor,
    required this.isHighlighted,
    this.highlightColor,
    required this.hasNote,
    this.englishText,
    required this.translationMode,
    this.tags,
    required this.onTap,
    this.onLongPress,
    this.isTtsActive = false,
    this.ttsStartChar,
    this.ttsEndChar,
    this.isSelected = false,
  });

  @override
  State<VerseItem> createState() => _VerseItemState();
}

class _VerseItemState extends State<VerseItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isHighlighted) {
      _startHighlightAnimation();
    }
  }

  @override
  void didUpdateWidget(VerseItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _startHighlightAnimation();
    }
  }

  void _startHighlightAnimation() {
    _controller.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.stop();
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<InlineSpan> _buildSpans(
    String fullText,
    bool isTtsActive,
    int? start,
    int? end,
    TextStyle style,
    Color primaryColor,
  ) {
    if (!isTtsActive || start == null || end == null || start < 0 || end > fullText.length || start >= end) {
      return [TextSpan(text: fullText, style: style)];
    }

    final prefix = fullText.substring(0, start);
    final word = fullText.substring(start, end);
    final suffix = fullText.substring(end);

    return [
      TextSpan(text: prefix, style: style),
      TextSpan(
        text: word,
        style: style.copyWith(
          backgroundColor: primaryColor.withValues(alpha: 0.25),
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
      TextSpan(text: suffix, style: style),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine persistent highlight background color
    Color containerColor = Colors.transparent;
    if (widget.highlightColor != null) {
      containerColor = widget.highlightColor!.withValues(alpha: isDark ? 0.20 : 0.35);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.primaryColor.withValues(alpha: isDark ? 0.25 : 0.15)
                : (widget.isHighlighted 
                    ? widget.primaryColor.withValues(alpha: _animation.value)
                    : containerColor),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected ? widget.primaryColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: child,
        );
      },
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: widget.fontSize,
                color: widget.textColor,
                height: 1.6,
                fontFamily: 'serif',
              ),
              children: [
                TextSpan(
                  text: '${widget.verse.verse}  ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.primaryColor,
                    fontSize: widget.fontSize - 2,
                  ),
                ),
                ..._buildSpans(
                  widget.translationMode == 'english' 
                      ? (widget.englishText ?? widget.verse.text)
                      : widget.verse.text,
                  widget.isTtsActive,
                  widget.ttsStartChar,
                  widget.ttsEndChar,
                  TextStyle(
                    fontSize: widget.fontSize,
                    color: widget.textColor,
                    height: 1.6,
                    fontFamily: 'serif',
                  ),
                  widget.primaryColor,
                ),
                if (widget.translationMode == 'parallel' && widget.englishText != null) ...[
                  const TextSpan(text: '\n'),
                  TextSpan(
                    text: widget.englishText!,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: widget.fontSize - 1.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
                if (widget.hasNote)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: Icon(
                        Icons.edit_note,
                        size: widget.fontSize + 2,
                        color: widget.primaryColor,
                      ),
                    ),
                  ),
                if (widget.tags != null && widget.tags!.isNotEmpty) ...[
                  const TextSpan(text: '\n'),
                  WidgetSpan(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Wrap(
                        spacing: 4.0,
                        runSpacing: 2.0,
                        children: widget.tags!.map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.primaryColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color ?? Theme.of(context).primaryColor, size: 26),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.label,
    required this.selected,
    required this.bgColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: bgColor,
        side: BorderSide(
          color: selected ? primaryColor : Colors.grey.withValues(alpha: 0.2),
          width: selected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TranslationOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TranslationOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
        backgroundColor: selected ? theme.primaryColor : Colors.transparent,
        side: BorderSide(color: selected ? theme.primaryColor : Colors.grey.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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