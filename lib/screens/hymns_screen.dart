import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/database_service.dart';
import '../models/hymn.dart';
import '../services/app_localizations.dart';
import '../widgets/book_page_fold.dart';
import '../models/original_hymn.dart';
import '../services/original_hymns_service.dart';

class HymnSearchResult {
  final Hymn hymn;
  final String? matchedSnippet;
  final String? matchedSnippetContext;
  final OriginalHymn? matchedOriginal;
  final bool matchedInNumber;
  final bool matchedInTitle;
  final bool matchedInLyrics;
  final bool matchedInOriginal;

  HymnSearchResult({
    required this.hymn,
    this.matchedSnippet,
    this.matchedSnippetContext,
    this.matchedOriginal,
    this.matchedInNumber = false,
    this.matchedInTitle = false,
    this.matchedInLyrics = false,
    this.matchedInOriginal = false,
  });
}

Widget buildHighlightedText({
  required String text,
  required String query,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
  TextAlign textAlign = TextAlign.start,
  int? maxLines,
  TextOverflow? overflow,
}) {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return Text(
      text,
      style: baseStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = trimmedQuery.toLowerCase();

  if (lowerText.contains(lowerQuery)) {
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      final matchEnd = index + trimmedQuery.length;
      spans.add(TextSpan(
        text: text.substring(index, matchEnd),
        style: highlightStyle,
      ));
      start = matchEnd;
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  final words = lowerQuery.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
  if (words.isNotEmpty && words.any((w) => lowerText.contains(w))) {
    final intervals = <List<int>>[];
    for (final word in words) {
      int s = 0;
      while (true) {
        final idx = lowerText.indexOf(word, s);
        if (idx < 0) break;
        intervals.add([idx, idx + word.length]);
        s = idx + word.length;
      }
    }
    intervals.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<int>>[];
    for (final interval in intervals) {
      if (merged.isEmpty || interval[0] > merged.last[1]) {
        merged.add(interval);
      } else if (interval[1] > merged.last[1]) {
        merged.last[1] = interval[1];
      }
    }

    final spans = <TextSpan>[];
    int cur = 0;
    for (final m in merged) {
      if (m[0] > cur) {
        spans.add(TextSpan(text: text.substring(cur, m[0]), style: baseStyle));
      }
      spans.add(TextSpan(text: text.substring(m[0], m[1]), style: highlightStyle));
      cur = m[1];
    }
    if (cur < text.length) {
      spans.add(TextSpan(text: text.substring(cur), style: baseStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  return Text(
    text,
    style: baseStyle,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

class HymnsScreen extends StatefulWidget {
  const HymnsScreen({super.key});

  @override
  State<HymnsScreen> createState() => HymnsScreenState();
}

class HymnsScreenState extends State<HymnsScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final OriginalHymnsService _originalHymnsService = OriginalHymnsService();
  Hymn? _selectedHymn;
  late TabController _tabController;

  final ScrollController _gushimishaScrollController = ScrollController();
  final ScrollController _agakizaScrollController = ScrollController();
  final ScrollController _sdaScrollController = ScrollController();

  // HUD and Beaming variables
  String? _hudText;
  bool _showHUDWidget = false;
  Timer? _hudTimer;

  int? _beamedGushimishaIndex;
  int? _beamedAgakizaIndex;
  int? _beamedSdaIndex;
  Timer? _beamTimer;

  // Active touch coordinate for fast-scroll magnification
  double? _activeTouchY;
  bool _isDraggingFastScroll = false;

  // Preloaded caching
  bool _isPreloading = true;
  List<Hymn> _allGushimishaHymns = [];
  List<Hymn> _allAgakizaHymns = [];
  List<Hymn> _allSdaHymns = [];
  List<String> _gushimishaCategories = [];
  List<String> _agakizaCategories = [];

  // Filtered lists
  List<Hymn> _filteredGushimishaList = [];
  List<Hymn> _filteredAgakizaList = [];
  List<Hymn> _filteredSdaList = [];

  // Selections
  String? _selectedGushimishaCategory;
  String? _selectedAgakizaCategory;
  String _selectedBook = 'indirimbo'; // 'indirimbo' or 'sda'

  // Search state across both books
  List<HymnSearchResult> _searchResults = [];
  String? _searchBookFilter; // null (Zose), 'gushimisha', 'agakiza'
  String? _activeSearchQuery;
  OriginalHymn? _activeMatchedOriginal;

  // Navigation state:
  // 0: Book cards selection list (first view)
  // 1: Hymns list (Tabbed for Indirimbo, unified list for SDA)
  int _currentView = 0;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _searchController.addListener(_onSearchChanged);
    _originalHymnsService.ensureLoaded();
    _preloadAllHymns();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _gushimishaScrollController.dispose();
    _agakizaScrollController.dispose();
    _sdaScrollController.dispose();
    _hudTimer?.cancel();
    _beamTimer?.cancel();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        if (_isSearching) {
          _isSearching = false;
          _searchController.clear();
          _searchResults = [];
          _searchBookFilter = null;
        }
      });
    }
  }

  Future<void> _preloadAllHymns() async {
    if (mounted) {
      setState(() => _isPreloading = true);
    }
    try {
      final gList = await _dbService.getHymnsByBook('Gushimisha');
      final gCats = await _dbService.getHymnCategories('Gushimisha');
      final aList = await _dbService.getHymnsByBook('Agakiza');
      final aCats = await _dbService.getHymnCategories('Agakiza');
      final sList = await _dbService.getHymnsByBook('SDA Hymnal');

      if (mounted) {
        setState(() {
          _allGushimishaHymns = gList;
          _gushimishaCategories = gCats;
          _allAgakizaHymns = aList;
          _agakizaCategories = aCats;
          _allSdaHymns = sList;
          _isPreloading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error preloading hymns: $e');
      if (mounted) {
        setState(() => _isPreloading = false);
      }
    }
  }

  void selectHymn(
    Hymn hymn, {
    String? initialSearchQuery,
    OriginalHymn? matchedOriginal,
  }) {
    setState(() {
      _selectedHymn = hymn;
      _activeSearchQuery = initialSearchQuery;
      _activeMatchedOriginal = matchedOriginal;
      _currentView = 1;
      if (hymn.book.toLowerCase() == 'sda hymnal') {
        _selectedBook = 'sda';
      } else {
        _selectedBook = 'indirimbo';
        final targetIndex = hymn.book.toLowerCase() == 'gushimisha' ? 0 : 1;
        if (_tabController.index != targetIndex) {
          _tabController.index = targetIndex;
        }
      }
    });
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      _applyFilters();
    });
  }

  void _onCategorySelected(String? category, bool isGushimisha) {
    setState(() {
      if (isGushimisha) {
        _selectedGushimishaCategory = category;
      } else {
        _selectedAgakizaCategory = category;
      }
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchController.text.trim();

    // 1. Filter Gushimisha
    List<Hymn> tempG = _allGushimishaHymns;
    if (_selectedGushimishaCategory != null) {
      tempG = tempG.where((hymn) => hymn.category == _selectedGushimishaCategory).toList();
    }

    // 2. Filter Agakiza
    List<Hymn> tempA = _allAgakizaHymns;
    if (_selectedAgakizaCategory != null) {
      tempA = tempA.where((hymn) => hymn.category == _selectedAgakizaCategory).toList();
    }

    // 3. Filter SDA
    List<Hymn> tempS = _allSdaHymns;

    List<HymnSearchResult> searchRes = [];
    if (_isSearching && query.isNotEmpty) {
      searchRes = _performSearch(query);
    }

    setState(() {
      _filteredGushimishaList = tempG;
      _filteredAgakizaList = tempA;
      _filteredSdaList = tempS;
      _searchResults = searchRes;
    });
  }

  List<HymnSearchResult> _performSearch(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final isNumeric = int.tryParse(q) != null;
    if (q.length < 2 && !isNumeric) return [];

    final results = <HymnSearchResult>[];
    final allHymns = _selectedBook == 'sda'
        ? _allSdaHymns
        : [..._allGushimishaHymns, ..._allAgakizaHymns];

    for (final hymn in allHymns) {
      final isGushimisha = hymn.book.toLowerCase() == 'gushimisha';
      final isSda = hymn.book.toLowerCase() == 'sda hymnal';
      final matchesNum = hymn.number.toString() == q;
      final matchesTitle = hymn.title.toLowerCase().contains(q);

      String? matchedSnippet;
      String? matchedSnippetContext;
      OriginalHymn? matchedOriginal;
      bool matchedInLyrics = false;
      bool matchedInOriginal = false;

      // 1. Check lyrics
      for (final block in hymn.lyrics) {
        for (final line in block.lines) {
          if (line.toLowerCase().contains(q)) {
            matchedSnippet = line.trim();
            matchedSnippetContext = isSda
                ? (block.type == 'chorus' ? 'Chorus' : 'Verse ${block.number ?? ""}')
                : (block.type == 'chorus' ? 'Inyikirizo' : 'Igitero ${block.number ?? ""}');
            matchedInLyrics = true;
            break;
          }
        }
        if (matchedInLyrics) break;
      }

      // If lyrics didn't match directly as a phrase, check if multi-word query words match
      if (!matchedInLyrics && q.contains(' ')) {
        final words = q.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
        if (words.isNotEmpty) {
          for (final block in hymn.lyrics) {
            for (final line in block.lines) {
              final lineLower = line.toLowerCase();
              if (words.every((w) => lineLower.contains(w))) {
                matchedSnippet = line.trim();
                matchedSnippetContext = isSda
                    ? (block.type == 'chorus' ? 'Chorus' : 'Verse ${block.number ?? ""}')
                    : (block.type == 'chorus' ? 'Inyikirizo' : 'Igitero ${block.number ?? ""}');
                matchedInLyrics = true;
                break;
              }
            }
            if (matchedInLyrics) break;
          }
        }
      }

      // 2. If Gushimisha, check original hymns (English/French)
      if (isGushimisha) {
        final originals = _originalHymnsService.getOriginals(hymn.book, hymn.number);
        for (final orig in originals) {
          if (orig.title.toLowerCase().contains(q)) {
            matchedOriginal ??= orig;
            matchedInOriginal = true;
            matchedSnippet ??= orig.title;
            matchedSnippetContext ??= '${orig.language} Title';
            break;
          }
          for (final block in orig.lyrics) {
            for (final line in block.lines) {
              if (line.toLowerCase().contains(q)) {
                matchedOriginal ??= orig;
                matchedInOriginal = true;
                matchedSnippet ??= line.trim();
                matchedSnippetContext ??= '${orig.language}: ${orig.title}';
                break;
              }
            }
            if (matchedInOriginal) break;
          }
          if (matchedInOriginal) break;
        }
      }

      if (matchesNum || matchesTitle || matchedInLyrics || matchedInOriginal) {
        results.add(HymnSearchResult(
          hymn: hymn,
          matchedSnippet: matchedSnippet,
          matchedSnippetContext: matchedSnippetContext,
          matchedOriginal: matchedOriginal,
          matchedInNumber: matchesNum,
          matchedInTitle: matchesTitle,
          matchedInLyrics: matchedInLyrics,
          matchedInOriginal: matchedInOriginal,
        ));
      }
    }

    results.sort((a, b) {
      final aScore = _computeScore(a, q);
      final bScore = _computeScore(b, q);
      if (aScore != bScore) {
        return bScore.compareTo(aScore);
      }
      return a.hymn.number.compareTo(b.hymn.number);
    });

    return results;
  }

  int _computeScore(HymnSearchResult res, String q) {
    if (res.matchedInNumber) return 100;
    if (res.matchedInTitle && res.hymn.title.toLowerCase().startsWith(q)) return 90;
    if (res.matchedInTitle) return 80;
    if (res.matchedInLyrics) return 60;
    if (res.matchedInOriginal) return 40;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedHymn != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            setState(() {
              _selectedHymn = null;
              _activeSearchQuery = null;
              _activeMatchedOriginal = null;
            });
          }
        },
        child: HymnDetailModal(
          hymn: _selectedHymn!,
          initialSearchQuery: _activeSearchQuery,
          initialOriginal: _activeMatchedOriginal,
          onBack: () => setState(() {
            _selectedHymn = null;
            _activeSearchQuery = null;
            _activeMatchedOriginal = null;
          }),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isPreloading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppLocalizations.translate('hymns_books_title'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return PopScope(
      canPop: _currentView == 0 && !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isSearching) {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _searchResults = [];
              _searchBookFilter = null;
            });
          } else {
            setState(() {
              _currentView = 0;
            });
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _currentView == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () {
                    if (_isSearching) {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        _searchResults = [];
                        _searchBookFilter = null;
                      });
                    } else {
                      setState(() {
                        _currentView = 0;
                      });
                    }
                  },
                )
              : null,
          title: _isSearching
              ? Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.translate('hymns_search_hint'),
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 14,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                    ),
                  ),
                )
              : Text(
                  _currentView == 1
                      ? (_selectedBook == 'sda' ? 'SDA HYMNAL' : 'INDIRIMBO')
                      : AppLocalizations.translate('hymns_books_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
          actions: [
            if (_currentView == 1)
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _searchResults = [];
                      _searchBookFilter = null;
                      _applyFilters();
                    }
                  });
                },
              ),
          ],
          bottom: (_currentView == 0 || _isSearching || _selectedBook == 'sda')
              ? null
              : TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'zo Gushimisha'),
                    Tab(text: "z'Agakiza"),
                  ],
                ),
        ),
        body: _currentView == 0
            ? _buildHymnBooksList(isDark)
            : _isSearching
                ? _buildSearchResultsView(isDark)
                : (_selectedBook == 'sda'
                    ? _buildSdaHymnsList(isDark)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildHymnsList(isDark, true),
                          _buildHymnsList(isDark, false),
                        ],
                      )),
      ),
    );
  }

  Widget _buildSearchResultsView(bool isDark) {
    final query = _searchController.text.trim();
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = isDark ? const Color(0xFF60A5FA) : primaryColor;

    if (query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search, size: 34, color: accentColor),
              ),
              const SizedBox(height: 18),
              Text(
                'Shakisha Indirimbo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Andika numero, umutwe, amagambo y\'indirimbo, cyangwa indirimbo zo mu Cyongereza n\'Igifaransa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (query.length < 2 && int.tryParse(query) == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, size: 48, color: isDark ? Colors.grey[500] : Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Andika nibura inyuguti 2',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Komeza wandike kugira ngo ubone indirimbo zose zifite ayo magambo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayedResults = _searchBookFilter == null
        ? _searchResults
        : _searchResults
            .where((r) => r.hymn.book.toLowerCase() == _searchBookFilter!.toLowerCase())
            .toList();

    if (displayedResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 56, color: isDark ? Colors.grey[500] : Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Nta ndirimbo yabonetse',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nta ndirimbo ihwanye na "$query" yabonetse.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final gushimishaCount = _searchResults.where((r) => r.hymn.book.toLowerCase() == 'gushimisha').length;
    final agakizaCount = _searchResults.where((r) => r.hymn.book.toLowerCase() == 'agakiza').length;

    return Column(
      children: [
        // Filter chips bar (only for multi-section Indirimbo book)
        if (_selectedBook == 'indirimbo') ...[
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(
                  label: Text('Zose (${_searchResults.length})', style: const TextStyle(fontSize: 12)),
                  selected: _searchBookFilter == null,
                  onSelected: (_) => setState(() => _searchBookFilter = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('zo Gushimisha ($gushimishaCount)', style: const TextStyle(fontSize: 12)),
                  selected: _searchBookFilter == 'gushimisha',
                  onSelected: (_) => setState(() => _searchBookFilter = _searchBookFilter == 'gushimisha' ? null : 'gushimisha'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('z\'Agakiza ($agakizaCount)', style: const TextStyle(fontSize: 12)),
                  selected: _searchBookFilter == 'agakiza',
                  onSelected: (_) => setState(() => _searchBookFilter = _searchBookFilter == 'agakiza' ? null : 'agakiza'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            itemCount: displayedResults.length,
            itemBuilder: (context, index) {
              final result = displayedResults[index];
              final hymn = result.hymn;
              final isGushimisha = hymn.book.toLowerCase() == 'gushimisha';
              final isSda = hymn.book.toLowerCase() == 'sda hymnal';
              final bookColor = isSda
                  ? const Color(0xFF0F766E)
                  : (isGushimisha ? (isDark ? const Color(0xFF60A5FA) : primaryColor) : const Color(0xFF10B981));

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    selectHymn(
                      hymn,
                      initialSearchQuery: query,
                      matchedOriginal: result.matchedOriginal,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: bookColor.withValues(alpha: 0.14),
                              child: Text(
                                '${hymn.number}',
                                style: TextStyle(
                                  color: isSda
                                      ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E))
                                      : (isGushimisha
                                          ? (isDark ? const Color(0xFF60A5FA) : primaryColor)
                                          : const Color(0xFF10B981)),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: bookColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isSda ? 'SDA Hymnal' : (isGushimisha ? 'Gushimisha' : 'Agakiza'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSda
                                                ? (isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E))
                                                : (isGushimisha
                                                    ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                                    : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  buildHighlightedText(
                                    text: hymn.title,
                                    query: query,
                                    baseStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    highlightStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: isDark ? Colors.white : Colors.black,
                                      backgroundColor: isDark
                                          ? const Color(0xFFCA8A04).withValues(alpha: 0.7)
                                          : const Color(0xFFFDE047),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          ],
                        ),
                        if (result.matchedSnippet != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (result.matchedSnippetContext != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      result.matchedSnippetContext!,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                buildHighlightedText(
                                  text: result.matchedSnippet!,
                                  query: query,
                                  baseStyle: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.3,
                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                  ),
                                  highlightStyle: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.3,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                    backgroundColor: isDark
                                        ? const Color(0xFFCA8A04).withValues(alpha: 0.7)
                                        : const Color(0xFFFDE047),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHymnBooksList(bool isDark) {
    final books = [
      {
        'id': 'indirimbo',
        'title': 'INDIRIMBO ZO GUSHIMISHA & AGAKIZA',
        'subtitle': 'Indirimbo 546 • Kinyarwanda',
        'image': 'assets/logo/indirimbo_logo.webp',
        'gradient': [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
        'abbrev': 'IZG',
      },
      {
        'id': 'sda',
        'title': 'SDA HYMNAL',
        'subtitle': 'Hymns 698 • English',
        'image': 'assets/logo/sda_hymnal_logo.webp',
        'gradient': [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
        'abbrev': 'SDA',
      },
    ];

    return RefreshIndicator(
      onRefresh: _preloadAllHymns,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              AppLocalizations.translate('hymns_books_title'),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: books.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              itemBuilder: (context, index) {
                final book = books[index];
                return _buildHymnBookCard(context, book, isDark);
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildHymnBookCard(BuildContext context, Map<String, dynamic> book, bool isDark) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBook = book['id'] as String;
          _currentView = 1;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      book['image'] as String,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        final gradient = book['gradient'] as List<Color>;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  book['abbrev'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                book['title'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: isDark ? Colors.white : const Color(0xFF374151),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                book['subtitle'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSdaHymnsList(bool isDark) {
    final list = _filteredSdaList;

    return RefreshIndicator(
      onRefresh: _preloadAllHymns,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(
                  child: Text('Nta ndirimbo yabonetse.', style: TextStyle(color: Colors.grey)),
                ),
              ],
            )
          : Stack(
              children: [
                ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _sdaScrollController,
                  padding: const EdgeInsets.only(left: 16, right: 56, top: 8, bottom: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final hymn = list[index];
                    final isBeamed = index == _beamedSdaIndex;
                    final hasMidi = hymn.midiFile != null && hymn.midiFile!.isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      elevation: isBeamed ? 3 : 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isBeamed
                              ? (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor)
                              : Colors.transparent,
                          width: isBeamed ? 2.0 : 0.0,
                        ),
                      ),
                      color: isBeamed
                          ? (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.18)
                          : null,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        minLeadingWidth: 32,
                        leading: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.12),
                            child: Text(
                              '${hymn.number}',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          hymn.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasMidi) ...[
                              Icon(
                                Icons.music_note_rounded,
                                size: 16,
                                color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 2),
                            ],
                            const Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                        onTap: () => selectHymn(hymn),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  bottom: 12,
                  width: 32,
                  child: _buildVerticalIndexer(context, list, 'sda'),
                ),
                if (_showHUDWidget && _hudText != null && _hudText!.isNotEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showHUDWidget ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _hudText ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHymnsList(bool isDark, bool isGushimisha) {
    final list = isGushimisha ? _filteredGushimishaList : _filteredAgakizaList;
    final categories = isGushimisha ? _gushimishaCategories : _agakizaCategories;
    final selectedCategory = isGushimisha ? _selectedGushimishaCategory : _selectedAgakizaCategory;

    return Column(
      children: [
        if (categories.isNotEmpty)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = selectedCategory == null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: const Text('Zose', style: TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (_) => _onCategorySelected(null, isGushimisha),
                    ),
                  );
                }

                final cat = categories[index - 1];
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      _onCategorySelected(selected ? cat : null, isGushimisha);
                    },
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _preloadAllHymns,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text('Nta ndirimbo yabonetse yujuje ibi bintu.', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: isGushimisha ? _gushimishaScrollController : _agakizaScrollController,
                      padding: const EdgeInsets.only(left: 16, right: 56, top: 8, bottom: 8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final hymn = list[index];
                        final isBeamed = isGushimisha 
                            ? index == _beamedGushimishaIndex 
                            : index == _beamedAgakizaIndex;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          elevation: isBeamed ? 3 : 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isBeamed 
                                  ? (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor)
                                  : Colors.transparent,
                              width: isBeamed ? 2.0 : 0.0,
                            ),
                          ),
                          color: isBeamed 
                              ? (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.18)
                              : null,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            minLeadingWidth: 32,
                            leading: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.12),
                                child: Text(
                                  '${hymn.number}',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              hymn.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 16),
                            onTap: () => selectHymn(hymn),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      bottom: 12,
                      width: 32,
                      child: _buildVerticalIndexer(context, list, isGushimisha ? 'gushimisha' : 'agakiza'),
                    ),
                    if (_showHUDWidget && _hudText != null && _hudText!.isNotEmpty)
                      Align(
                        alignment: Alignment.center,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _showHUDWidget ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _hudText ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    ],
  );
}

  void _showHUD(String text) {
    if (_hudTimer != null) {
      _hudTimer!.cancel();
    }
    setState(() {
      _hudText = text;
      _showHUDWidget = true;
    });
  }

  void _hideHUD() {
    _hudTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showHUDWidget = false;
        });
      }
    });
  }

  Widget _buildVerticalIndexer(BuildContext context, List<Hymn> list, String bookType) {
    if (list.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = bookType == 'gushimisha'
        ? _gushimishaScrollController
        : (bookType == 'agakiza' ? _agakizaScrollController : _sdaScrollController);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Calculate current scroll progress if scroll controller has clients
        double scrollPercent = 0.0;
        try {
          if (controller.hasClients &&
              controller.positions.length == 1 &&
              controller.position.hasContentDimensions) {
            final maxExtent = controller.position.maxScrollExtent;
            if (maxExtent > 0) {
              scrollPercent = (controller.offset / maxExtent).clamp(0.0, 1.0);
            }
          }
        } catch (_) {}

        return LayoutBuilder(
          builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;
        const handleHeight = 48.0;
        const handleWidth = 14.0;
        const trackWidth = 24.0;

        // Determine current handle center Y
        double handleCenterY;
        if (_isDraggingFastScroll && _activeTouchY != null) {
          handleCenterY = _activeTouchY!.clamp(handleHeight / 2, trackHeight - handleHeight / 2);
        } else {
          handleCenterY = scrollPercent * (trackHeight - handleHeight) + (handleHeight / 2);
        }

        // Map handleCenterY to the list index
        double dragPercent = ((handleCenterY - handleHeight / 2) / (trackHeight - handleHeight)).clamp(0.0, 1.0);
        int targetIndex = (dragPercent * (list.length - 1)).round().clamp(0, list.length - 1);
        final targetHymn = list[targetIndex];

        void onTouch(double localY) {
          setState(() {
            _isDraggingFastScroll = true;
            _activeTouchY = localY;
          });

          // Show HUD continuously with target song number
          _showHUD('${targetHymn.number}');
        }

        void onTouchEnd() {
          setState(() {
            _isDraggingFastScroll = false;
            _activeTouchY = null;
          });
          _hideHUD();

          // Scroll list to corresponding song
          if (controller.hasClients && list.isNotEmpty) {
            try {
              if (controller.positions.length == 1 &&
                  controller.position.hasContentDimensions) {
                final maxScroll = controller.position.maxScrollExtent;
                final double targetOffset = (list.length > 1)
                    ? (targetIndex / (list.length - 1)) * maxScroll
                    : 0.0;
                controller.jumpTo(targetOffset.clamp(0.0, maxScroll));
              }
            } catch (_) {}
          }

          // Beam highlight effect
          setState(() {
            if (bookType == 'gushimisha') {
              _beamedGushimishaIndex = targetIndex;
            } else if (bookType == 'agakiza') {
              _beamedAgakizaIndex = targetIndex;
            } else {
              _beamedSdaIndex = targetIndex;
            }
          });

          if (_beamTimer != null) {
            _beamTimer!.cancel();
          }
          _beamTimer = Timer(const Duration(milliseconds: 1200), () {
            if (mounted) {
              setState(() {
                _beamedGushimishaIndex = null;
                _beamedAgakizaIndex = null;
                _beamedSdaIndex = null;
              });
            }
          });
        }

        final activeColor = isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor;

        return GestureDetector(
          onVerticalDragStart: (details) => onTouch(details.localPosition.dy),
          onVerticalDragUpdate: (details) => onTouch(details.localPosition.dy),
          onVerticalDragEnd: (_) => onTouchEnd(),
          onTapDown: (details) => onTouch(details.localPosition.dy),
          onTapUp: (_) => onTouchEnd(),
          child: Container(
            width: trackWidth,
            height: trackHeight,
            color: Colors.transparent, // Expand touch target area
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Visual vertical track line
                Positioned(
                  top: handleHeight / 2,
                  bottom: handleHeight / 2,
                  width: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.08) 
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Draggable handle/thumb
                Positioned(
                  top: handleCenterY - (handleHeight / 2),
                  width: _isDraggingFastScroll ? handleWidth * 1.3 : handleWidth,
                  height: handleHeight,
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isDraggingFastScroll 
                            ? activeColor 
                            : (isDark ? Colors.white54 : Colors.black45),
                        borderRadius: BorderRadius.circular(handleWidth),
                        boxShadow: [
                          if (_isDraggingFastScroll)
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          else
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);
}
}

class HymnDetailModal extends StatefulWidget {
  final Hymn hymn;
  final VoidCallback? onBack;
  final String? initialSearchQuery;
  final OriginalHymn? initialOriginal;

  const HymnDetailModal({
    super.key,
    required this.hymn,
    this.onBack,
    this.initialSearchQuery,
    this.initialOriginal,
  });

  @override
  State<HymnDetailModal> createState() => _HymnDetailModalState();
}

class _HymnDetailModalState extends State<HymnDetailModal> {
  final DatabaseService _dbService = DatabaseService();
  final OriginalHymnsService _originalHymnsService = OriginalHymnsService();
  late Hymn _currentHymn;
  OriginalHymn? _selectedOriginal;
  String? _highlightQuery;
  bool _isFav = false;
  double _fontSize = 16.0;
  bool _canTurnForward = true;
  bool _canTurnBackward = false;

  AudioPlayer? _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoadingAudio = false;
  OriginalHymn? _activePlayingTrack;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _completeSubscription;

  @override
  void initState() {
    super.initState();
    _currentHymn = widget.hymn;
    _selectedOriginal = widget.initialOriginal;
    _highlightQuery = widget.initialSearchQuery;
    _canTurnBackward = _currentHymn.number > 1;
    _initAudioPlayer();
    _originalHymnsService.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _checkFavorite();
    _refreshTurnAvailability();
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _playerStateSubscription = _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          _isLoadingAudio = false;
        });
      }
    });

    _positionSubscription = _audioPlayer!.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _durationSubscription = _audioPlayer!.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur);
      }
    });

    _completeSubscription = _audioPlayer!.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _playerState = PlayerState.stopped;
          _activePlayingTrack = null;
        });
      }
    });
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isLoadingAudio = false;
        _activePlayingTrack = null;
      });
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completeSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _playTrack(OriginalHymn track) async {
    final assetPath = track.midiAssetPath;
    if (assetPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nta dosiye ya MIDI ihari kuri iyi ndirimbo.')),
      );
      return;
    }

    setState(() {
      _activePlayingTrack = track;
      _isLoadingAudio = true;
    });

    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing MIDI: $e');
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
          _playerState = PlayerState.stopped;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ikosa mu gucuranga MIDI: $e')),
        );
      }
    }
  }

  Future<void> _playSdaMidi(String path) async {
    setState(() {
      _isLoadingAudio = true;
      _activePlayingTrack = null;
    });

    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.play(AssetSource(path));
    } catch (e) {
      debugPrint('Error playing SDA MIDI: $e');
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
          _playerState = PlayerState.stopped;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ikosa mu gucuranga MIDI: $e')),
        );
      }
    }
  }

  void _handlePlayPressed() {
    final isSda = _currentHymn.book.toLowerCase() == 'sda hymnal';
    if (isSda) {
      if (_currentHymn.midiFile == null || _currentHymn.midiFile!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nta muziki wa MIDI uhari kuri iyi ndirimbo.')),
        );
        return;
      }

      if (_playerState == PlayerState.playing) {
        _audioPlayer?.pause();
        return;
      }

      if (_playerState == PlayerState.paused) {
        _audioPlayer?.resume();
        return;
      }

      _playSdaMidi(_currentHymn.midiFile!);
      return;
    }

    final isGushimisha = _currentHymn.book.toLowerCase() == 'gushimisha';
    if (!isGushimisha) return;

    final originals = _originalHymnsService.getOriginals(_currentHymn.book, _currentHymn.number);
    final validTracks = originals.where((o) => o.midiAssetPath != null).toList();

    if (validTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nta muziki wa MIDI uhari kuri iyi ndirimbo.')),
      );
      return;
    }

    if (_playerState == PlayerState.playing) {
      _audioPlayer?.pause();
      return;
    }

    if (_playerState == PlayerState.paused) {
      _audioPlayer?.resume();
      return;
    }

    // If only one track exists, play it directly
    if (validTracks.length == 1) {
      _playTrack(validTracks.first);
      return;
    }

    // If a track was already chosen, replay it
    if (_activePlayingTrack != null) {
      _playTrack(_activePlayingTrack!);
      return;
    }

    // Multiple tracks: prompt user with actual song titles
    _showTrackSelectionModal(validTracks);
  }

  void _showTrackSelectionModal(List<OriginalHymn> tracks) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = isDark ? const Color(0xFF60A5FA) : primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.music_note_rounded, color: accentColor, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Hitamo indirimbo wumva (MIDI)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                ...tracks.map((track) {
                  final isSelected = _activePlayingTrack == track;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: accentColor.withValues(alpha: isSelected ? 0.25 : 0.1),
                      child: Icon(
                        isSelected ? Icons.play_arrow_rounded : Icons.audiotrack_rounded,
                        color: accentColor,
                      ),
                    ),
                    title: Text(
                      track.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      track.language.isNotEmpty
                          ? '${track.language} version'
                          : 'Original tune',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: accentColor)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _playTrack(track);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildAppBarTitle(bool isDark, Color accentColor, List<OriginalHymn> validTracks) {
    final bool isAudioActive = _playerState == PlayerState.playing ||
        _playerState == PlayerState.paused ||
        _isLoadingAudio;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: isAudioActive
          ? _buildProgressBarView(isDark, accentColor, validTracks)
          : _buildSongTitleView(isDark, accentColor),
    );
  }

  Widget _buildSongTitleView(bool isDark, Color accentColor) {
    final title = _selectedOriginal != null
        ? '${_currentHymn.number}. ${_selectedOriginal!.title}'
        : '${_currentHymn.number}. ${_currentHymn.title}';

    return SizedBox(
      key: const ValueKey('song_title_view'),
      width: double.infinity,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildProgressBarView(bool isDark, Color accentColor, List<OriginalHymn> validTracks) {
    final maxVal = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final curVal = _position.inMilliseconds.toDouble().clamp(0.0, maxVal);
    final progressAccent = isDark ? const Color(0xFF60A5FA) : const Color(0xFF93C5FD);
    final progressTrackActive = isDark ? const Color(0xFF60A5FA) : Colors.white;
    final durationColor = isDark ? Colors.grey[300]! : Colors.white.withValues(alpha: 0.9);
    final totalDurationColor = isDark ? Colors.grey[400]! : Colors.white70;
    final closeColor = isDark ? Colors.grey[400]! : Colors.white70;

    return Container(
      key: const ValueKey('progress_bar_view'),
      height: 48,
      padding: const EdgeInsets.only(right: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: durationColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: (_activePlayingTrack != null || _currentHymn.book.toLowerCase() == 'sda hymnal')
                    ? InkWell(
                        onTap: validTracks.length > 1
                            ? () => _showTrackSelectionModal(validTracks)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _activePlayingTrack != null
                                    ? _activePlayingTrack!.title
                                    : '${_currentHymn.number}. ${_currentHymn.title}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: progressAccent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (validTracks.length > 1) ...[
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_drop_down, size: 14, color: progressAccent),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: totalDurationColor,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _stopAudio,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: closeColor,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
              activeTrackColor: progressTrackActive,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
              thumbColor: progressTrackActive,
            ),
            child: SizedBox(
              height: 18,
              child: Slider(
                value: curVal,
                min: 0.0,
                max: maxVal,
                onChanged: (value) {
                  _audioPlayer?.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshTurnAvailability() async {
    final next = await _dbService.getHymnByBookAndNumber(
      _currentHymn.book,
      _currentHymn.number + 1,
    );
    if (!mounted) return;
    setState(() {
      _canTurnForward = next != null;
      _canTurnBackward = _currentHymn.number > 1;
    });
  }

  Future<Hymn?> _adjacentHymn(BookPageTurnDirection direction) async {
    final number = direction == BookPageTurnDirection.forward
        ? _currentHymn.number + 1
        : _currentHymn.number - 1;
    if (number < 1) return null;
    return _dbService.getHymnByBookAndNumber(_currentHymn.book, number);
  }

  Future<void> _onBookPageTurn(BookPageTurnDirection direction) async {
    final target = await _adjacentHymn(direction);
    if (target == null || !mounted) return;
    await _stopAudio();
    setState(() {
      _currentHymn = target;
      _selectedOriginal = null;
      _highlightQuery = null;
    });
    await _checkFavorite();
    await _refreshTurnAvailability();
  }

  Future<Widget?> _loadDestinationPage(BookPageTurnDirection direction) async {
    final target = await _adjacentHymn(direction);
    if (target == null || !mounted) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return ColoredBox(
      color: bg,
      child: _buildHymnBody(
        target,
        isDark: isDark,
        primaryColor: primaryColor,
        scrollable: false,
        activeOriginal: null,
      ),
    );
  }

  Future<void> _checkFavorite() async {
    final status = await _dbService.isFavorite('hymn', _currentHymn.id!);
    if (mounted) {
      setState(() => _isFav = status);
    }
  }

  void _showSettingsBottomSheet() {
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
                  Text(
                    AppLocalizations.translate('reader_settings_font_size'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddToPlaylistDialog() async {
    final playlists = await _dbService.getPlaylists();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final newPlaylistController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ongeraho mu Rutonde (Playlist)'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (playlists.isEmpty)
                      const Text('Nta ntonde zihari. Banza ukore urutonde rushya!', style: TextStyle(color: Colors.grey, fontSize: 13))
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final pl = playlists[index];
                            return ListTile(
                              leading: const Icon(Icons.playlist_play),
                              title: Text(pl['name']),
                              onTap: () async {
                                await _dbService.addHymnToPlaylist(pl['id'], _currentHymn.id!);
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Yongewe kuri "${pl['name']}"!')),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPlaylistController,
                      decoration: const InputDecoration(
                        hintText: 'Andika izina ry\'urutonde rushya...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Reka'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = newPlaylistController.text.trim();
                    if (name.isNotEmpty) {
                      final plId = await _dbService.createPlaylist(name);
                      if (plId > 0) {
                        await _dbService.addHymnToPlaylist(plId, _currentHymn.id!);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Uruhande rwashyizweho neza kandi indirimbo yongewemo!')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Kora & Ongeraho'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVersionSelector(
    List<OriginalHymn> originals,
    bool isDark,
    Color primaryColor,
  ) {
    final accentColor = isDark ? const Color(0xFF60A5FA) : primaryColor;
    final bool isOriginActive = _selectedOriginal != null;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(3),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kinyarwanda Tab
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedOriginal = null),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: !isOriginActive ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Kinyarwanda',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: !isOriginActive
                          ? Colors.white
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ),
            // Origin Tab
            Expanded(
              child: originals.length == 1
                  ? InkWell(
                      onTap: () => setState(() => _selectedOriginal = originals.first),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: isOriginActive ? accentColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Origin',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isOriginActive
                                ? Colors.white
                                : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ),
                      ),
                    )
                  : PopupMenuButton<OriginalHymn>(
                      tooltip: 'Hitamo indirimbo y\'umwimerere',
                      offset: const Offset(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      onSelected: (orig) {
                        setState(() => _selectedOriginal = orig);
                      },
                      itemBuilder: (context) => originals.map((orig) {
                        final isSel = _selectedOriginal == orig;
                        return PopupMenuItem<OriginalHymn>(
                          value: orig,
                          height: 38,
                          child: Row(
                            children: [
                              Icon(
                                isSel ? Icons.check_circle : Icons.audiotrack,
                                size: 16,
                                color: isSel ? accentColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${orig.title} (${orig.language})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? accentColor : (isDark ? Colors.white : Colors.black87),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: isOriginActive ? accentColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Origin',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isOriginActive
                                    ? Colors.white
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 14,
                              color: isOriginActive
                                  ? Colors.white
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHymnBody(
    Hymn hymn, {
    required bool isDark,
    required Color primaryColor,
    required bool scrollable,
    OriginalHymn? activeOriginal,
  }) {
    final isGushimisha = hymn.book.toLowerCase() == 'gushimisha';
    final originals = isGushimisha
        ? _originalHymnsService.getOriginals(hymn.book, hymn.number)
        : const <OriginalHymn>[];

    final displayLyrics = activeOriginal != null
        ? activeOriginal.lyrics
        : hymn.lyrics;

    return SingleChildScrollView(
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isGushimisha && originals.isNotEmpty && scrollable) ...[
            _buildVersionSelector(originals, isDark, primaryColor),
            const SizedBox(height: 12),
          ],
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayLyrics.length,
            itemBuilder: (context, index) {
              final block = displayLyrics[index];
              final isChorus = block.type == 'chorus';

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: isChorus
                    ? const EdgeInsets.symmetric(vertical: 12, horizontal: 16)
                    : null,
                decoration: isChorus
                    ? BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1D2436)
                            : const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark
                                  ? const Color(0xFF60A5FA)
                                  : primaryColor)
                              .withValues(alpha: 0.12),
                          width: 1,
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isChorus || block.number != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          isChorus ? 'Ch.' : '${block.number}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _fontSize - 1,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFF60A5FA)
                                : primaryColor,
                          ),
                        ),
                      ),
                    ...block.lines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: buildHighlightedText(
                          text: line,
                          query: _highlightQuery ?? '',
                          baseStyle: TextStyle(
                            fontSize: _fontSize,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          highlightStyle: TextStyle(
                            fontSize: _fontSize,
                            height: 1.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                            backgroundColor: isDark
                                ? const Color(0xFFCA8A04).withValues(alpha: 0.7)
                                : const Color(0xFFFDE047),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = Theme.of(context).scaffoldBackgroundColor;
    final accentColor = isDark ? const Color(0xFF60A5FA) : primaryColor;
    final appBarPlayBtnColor = isDark ? const Color(0xFF60A5FA) : Colors.white;

    final isGushimisha = _currentHymn.book.toLowerCase() == 'gushimisha';
    final isSda = _currentHymn.book.toLowerCase() == 'sda hymnal';
    final originals = isGushimisha
        ? _originalHymnsService.getOriginals(_currentHymn.book, _currentHymn.number)
        : const <OriginalHymn>[];
    final validTracks = originals.where((o) => o.midiAssetPath != null).toList();
    final hasMidi = isSda
        ? (_currentHymn.midiFile != null && _currentHymn.midiFile!.isNotEmpty)
        : (isGushimisha && validTracks.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: hasMidi ? 96.0 : 56.0,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            if (hasMidi)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: _isLoadingAudio
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(appBarPlayBtnColor),
                        ),
                      )
                    : Icon(
                        _playerState == PlayerState.playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        size: 28,
                        color: appBarPlayBtnColor,
                      ),
                onPressed: _handlePlayPressed,
              ),
          ],
        ),
        title: _buildAppBarTitle(isDark, accentColor, validTracks),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'text_settings') {
                _showSettingsBottomSheet();
              } else if (value == 'playlist') {
                _showAddToPlaylistDialog();
              } else if (value == 'favorite') {
                if (_isFav) {
                  await _dbService.removeFavorite('hymn', _currentHymn.id!);
                } else {
                  await _dbService.addFavorite('hymn', _currentHymn.id!);
                }
                setState(() => _isFav = !_isFav);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isFav ? 'Yabitswe mu Byatoranyijwe!' : 'Mukuraho!'))
                  );
                }
              } else if (value == 'copy') {
                // Copy current lyrics as plain text
                final buffer = StringBuffer();
                final activeTitle = _selectedOriginal != null ? _selectedOriginal!.title : _currentHymn.title;
                final activeLang = _selectedOriginal != null ? ' (${_selectedOriginal!.language})' : ' (${_currentHymn.book})';
                buffer.writeln('${_currentHymn.number}. $activeTitle$activeLang\n');
                final activeLyrics = _selectedOriginal != null ? _selectedOriginal!.lyrics : _currentHymn.lyrics;
                for (var block in activeLyrics) {
                  if (block.type == 'chorus') {
                    buffer.writeln('[Chorus/Gusubiramo]');
                  } else {
                    buffer.writeln('[Verse ${block.number ?? ""}]');
                  }
                  for (var line in block.lines) {
                    buffer.writeln(line);
                  }
                  buffer.writeln();
                }
                Clipboard.setData(ClipboardData(text: buffer.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Indirimbo yakopijwe yose!'))
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'text_settings',
                child: Row(
                  children: [
                    Icon(Icons.format_size, size: 20, color: isDark ? const Color(0xFF60A5FA) : primaryColor),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.translate('reader_settings_title')),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: isDark ? const Color(0xFF60A5FA) : primaryColor),
                    const SizedBox(width: 12),
                    const Text('Ongeraho mu rutonde'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'favorite',
                child: Row(
                  children: [
                    Icon(
                      _isFav ? Icons.favorite : Icons.favorite_border,
                      color: _isFav ? Colors.red : (isDark ? const Color(0xFF60A5FA) : primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Text(_isFav ? 'Kura mu byatoranyijwe' : 'Ongeraho mu byatoranyijwe'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, color: isDark ? const Color(0xFF60A5FA) : primaryColor),
                    const SizedBox(width: 12),
                    const Text('Kopiya (Copy)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Thinner/Smaller Quick Access Font Size Slider Bar (attached under top bar, exact Bible reader style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            height: 36,
            decoration: BoxDecoration(
              color: paperColor,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: isDark ? 0.15 : 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.text_fields,
                  size: 14,
                  color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.6),
                ),
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
                      activeColor: isDark ? const Color(0xFF60A5FA) : primaryColor,
                      inactiveColor: (isDark ? const Color(0xFF60A5FA) : primaryColor).withValues(alpha: 0.2),
                      onChanged: (val) {
                        setState(() => _fontSize = val);
                      },
                    ),
                  ),
                ),
                Icon(
                  Icons.text_fields,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ],
            ),
          ),
          Expanded(
            child: BookPageFold(
              canTurnForward: _canTurnForward,
              canTurnBackward: _canTurnBackward,
              paperColor: paperColor,
              onTurn: _onBookPageTurn,
              loadDestinationPage: _loadDestinationPage,
              child: _buildHymnBody(
                _currentHymn,
                isDark: isDark,
                primaryColor: primaryColor,
                scrollable: true,
                activeOriginal: _selectedOriginal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}