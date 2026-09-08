import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bible_reader_screen.dart';
import 'bible_selection_screen.dart';
import 'hymns_screen.dart';
import '../services/database_service.dart';
import '../models/hymn.dart';
import '../models/bible_book.dart';
import '../main.dart';
import '../services/app_state_service.dart';
import '../services/app_localizations.dart';
import '../services/daily_verse_service.dart';
import '../services/widget_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 2;
  final Set<int> _activatedTabs = {2};
  final GlobalKey<BibleReaderScreenState> _bibleReaderKey = GlobalKey<BibleReaderScreenState>();
  final GlobalKey<HymnsScreenState> _hymnsScreenKey = GlobalKey<HymnsScreenState>();
  String? _activeBibleId;

  String? get activeBibleId => _activeBibleId;

  @override
  void initState() {
    super.initState();
    _loadActiveBibleId();
    _syncWidgetData();
  }

  Future<void> _loadActiveBibleId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeBibleId = prefs.getString('active_bible_id');
    });
  }

  void clearActiveBible() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_bible_id');
    setState(() {
      _activeBibleId = null;
    });
  }

  void _syncWidgetData() async {
    try {
      await WidgetService.syncWidgetData();
    } catch (_) {}
  }

  void setTab(int index) {
    setState(() {
      _activatedTabs.add(index);
      _currentTabIndex = index;
    });
  }

  void navigateToBibleVerse(BibleBook book, int chapter, int verse) async {
    final prefs = await SharedPreferences.getInstance();
    if (_activeBibleId == null) {
      await prefs.setString('active_bible_id', 'BY');
      setState(() {
        _activeBibleId = 'BY';
      });
    }
    setState(() {
      _activatedTabs.add(0);
      _currentTabIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bibleReaderKey.currentState?.jumpToVerse(book, chapter, verse);
    });
  }

  void navigateToHymn(Hymn hymn) {
    setState(() {
      _activatedTabs.add(1);
      _currentTabIndex = 1; // Switch to Hymns tab
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hymnsScreenKey.currentState?.selectHymn(hymn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              _activatedTabs.contains(0)
                  ? (_activeBibleId == null
                      ? BibleSelectionScreen(
                          onBibleSelected: _loadActiveBibleId,
                        )
                      : BibleReaderScreen(key: _bibleReaderKey))
                  : const SizedBox.shrink(),
              _activatedTabs.contains(1)
                  ? HymnsScreen(key: _hymnsScreenKey)
                  : const SizedBox.shrink(),
              _activatedTabs.contains(2)
                  ? const DashboardTab()
                  : const SizedBox.shrink(),
              _activatedTabs.contains(3)
                  ? const SavedItemsTab()
                  : const SizedBox.shrink(),
              _activatedTabs.contains(4)
                  ? const SettingsScreen()
                  : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: Container(
            height: 84,
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Background bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 66,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? primaryColor
                          : const Color(0xFF1E1E1E),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Tab 0: Bible
                        _buildCustomNavItem(0, Icons.menu_book_outlined, Icons.menu_book, AppLocalizations.translate('nav_bible')),
                        // Tab 1: Hymns
                        _buildCustomNavItem(1, Icons.music_note_outlined, Icons.music_note, AppLocalizations.translate('nav_hymns')),
                        
                        // Spacer for middle floating button
                        const Expanded(child: SizedBox()),
                        
                        // Tab 3: Saved
                        _buildCustomNavItem(3, Icons.favorite_border, Icons.favorite, AppLocalizations.translate('nav_saved')),
                        // Tab 4: Settings
                        _buildCustomNavItem(4, Icons.settings_outlined, Icons.settings, AppLocalizations.translate('settings_title')),
                      ],
                    ),
                  ),
                ),
                // Floating Home Button
                Positioned(
                  top: 0,
                  child: _buildFloatingHomeButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentTabIndex == index;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final activeColor = isLight ? Colors.white : const Color(0xFF60A5FA);
    final inactiveColor = isLight ? Colors.white.withValues(alpha: 0.55) : Colors.grey.shade500;

    return Expanded(
      child: InkWell(
        onTap: () => setTab(index),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingHomeButton() {
    final isSelected = _currentTabIndex == 2;
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    final gradient = isSelected
        ? const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: isLight
                ? [Colors.white, Colors.grey.shade100]
                : [const Color(0xFF2D2D2D), const Color(0xFF1E1E1E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final border = Border.all(
      color: isSelected
          ? const Color(0xFF60A5FA).withValues(alpha: 0.5)
          : (isLight ? Colors.grey.shade300 : const Color(0xFF3E3E3E)),
      width: 1.5,
    );

    return GestureDetector(
      onTap: () => setTab(2),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          border: border,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF1D4ED8).withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            isSelected ? Icons.home_rounded : Icons.home_outlined,
            color: isSelected ? Colors.white : (isLight ? const Color(0xFF4B5563) : Colors.white),
            size: 26,
          ),
        ),
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic> _stats = {};
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _dbService.getDevotionStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  DailyVerseRef get _todayVerseRef => DailyVerseService.todayVerseRef();

  BibleBook _getBook(int bookNumber) {
    return BibleBook.allBooks.firstWhere(
      (b) => b.bookNumber == bookNumber,
      orElse: () => BibleBook.allBooks.first,
    );
  }

  Future<Map<String, String>> _fetchTodayVerse(String translationMode) async {
    final ref = _todayVerseRef;
    final book = _getBook(ref.bookNumber);
    final isEnglish = translationMode == 'english';
    final text = await _dbService.getSingleVerseText(ref.bookNumber, ref.chapter, ref.verse, isEnglish);
    final bookName = book.getDisplayName(translationMode);
    return {
      'ref': '$bookName ${ref.chapter}:${ref.verse}',
      'text': text ?? '',
    };
  }

  void _navigateToVerseRef(DailyVerseRef ref) {
    final bookObj = _getBook(ref.bookNumber);
    final parentState = context.findAncestorStateOfType<HomeScreenState>();
    parentState?.navigateToBibleVerse(bookObj, ref.chapter, ref.verse);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo/Gospel hub logo.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
            const Text(
              'Gospel Hub',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Colors.white,
            ),
            tooltip: isDark ? AppLocalizations.translate('theme_light_mode') : AppLocalizations.translate('theme_dark_mode'),
            onPressed: () async {
              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
              themeNotifier.value = newMode;
              await AppStateService.setDarkMode(newMode == ThemeMode.dark);
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
            ),
            tooltip: AppLocalizations.translate('settings_title'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStats();
          if (mounted) setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Verse Card
            ValueListenableBuilder<String>(
              valueListenable: bibleTranslationNotifier,
              builder: (context, translationMode, _) {
                return FutureBuilder<Map<String, String>>(
                  future: _fetchTodayVerse(translationMode),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    final verseData = snapshot.data!;
                    final verseText = verseData['text']!;
                    final verseRef = verseData['ref']!;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _navigateToVerseRef(_todayVerseRef),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark 
                                  ? [const Color(0xFF1A365D), const Color(0xFF1B1D1B)]
                                  : [const Color(0xFF273E82), const Color(0xFF1B264F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: isDark ? const Color(0xFF60A5FA) : Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.translate('dash_verse_of_day'),
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '"$verseText"',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                  fontFamily: 'serif',
                                  color: isDark ? Colors.white70 : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    verseRef,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.copy_outlined, 
                                          size: 20,
                                          color: isDark ? null : Colors.white.withValues(alpha: 0.85),
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(
                                            text: '$verseText ($verseRef)'
                                          ));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(AppLocalizations.translate('verse_copied')))
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.share_outlined, 
                                          size: 20,
                                          color: isDark ? null : Colors.white.withValues(alpha: 0.85),
                                        ),
                                        onPressed: () {
                                          SharePlus.instance.share(
                                            ShareParams(
                                              text: '"$verseText"\n\n— $verseRef',
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Devotional Habit Statistics Card
            if (!_loadingStats) ...[
              Text(
                AppLocalizations.translate('dash_stats'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  '${_stats['streak'] ?? 0}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.translate('dash_streak'),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      elevation: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: isDark ? const Color(0xFF60A5FA) : primaryColor, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  '${_stats['total_chapters'] ?? 0}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.translate('dash_chapters'),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recently Read Chapters (Quick resumption)
              if (_stats['recently_read'] != null && (_stats['recently_read'] as List).isNotEmpty) ...[
                Text(
                  AppLocalizations.translate('dash_recently_read'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0.5,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (_stats['recently_read'] as List).length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = _stats['recently_read'][idx];
                      final bookObj = BibleBook.getByNumber(item['book']);
                      return ListTile(
                        leading: Icon(Icons.history, color: isDark ? const Color(0xFF60A5FA) : primaryColor, size: 20),
                        title: Text(
                          '${bookObj.name} Igice cya ${item['chapter']}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () {
                          final parentState = context.findAncestorStateOfType<HomeScreenState>();
                          parentState?.navigateToBibleVerse(bookObj, item['chapter'], 1);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],

            // Navigation Links Title
            Text(
              AppLocalizations.translate('dash_categories'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Card list for main features
            _MenuCard(
              title: AppLocalizations.translate('nav_bible'),
              subtitle: AppLocalizations.translate('dash_bible_desc'),
              icon: Icons.menu_book,
              color: isDark ? const Color(0xFF60A5FA) : primaryColor,
              onTap: () {
                // Switch to Bible tab
                final parentState = context.findAncestorStateOfType<HomeScreenState>();
                parentState?.setState(() {
                  parentState._currentTabIndex = 0;
                });
              },
            ),
            const SizedBox(height: 12),
            _MenuCard(
              title: AppLocalizations.translate('dash_hymns_title'),
              subtitle: AppLocalizations.translate('dash_hymns_desc'),
              icon: Icons.music_note,
              color: const Color(0xFF00A8FF),
              onTap: () {
                // Switch to Hymns tab
                final parentState = context.findAncestorStateOfType<HomeScreenState>();
                parentState?.setState(() {
                  parentState._currentTabIndex = 1;
                });
              },
            ),
            const SizedBox(height: 12),
            _MenuCard(
              title: AppLocalizations.translate('nav_saved'),
              subtitle: AppLocalizations.translate('dash_saved_desc'),
              icon: Icons.favorite,
              color: Colors.red.shade600,
              onTap: () {
                // Switch to Saved tab
                final parentState = context.findAncestorStateOfType<HomeScreenState>();
                parentState?.setState(() {
                  parentState._currentTabIndex = 3;
                });
              },
            ),
          ],
        ),
      ),
    ),
  );
},
);
}
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedItemsTab extends StatefulWidget {
  const SavedItemsTab({super.key});

  @override
  State<SavedItemsTab> createState() => _SavedItemsTabState();
}

class _SavedItemsTabState extends State<SavedItemsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();
  
  List<Map<String, dynamic>> _savedVerses = [];
  List<Map<String, dynamic>> _savedHymns = [];
  List<Map<String, dynamic>> _savedNotes = [];
  List<Map<String, dynamic>> _savedHighlights = [];
  List<String> _uniqueTags = [];
  String? _selectedTagFilter;
  List<Map<String, dynamic>> _taggedVerses = [];
  
  List<Map<String, dynamic>> _playlists = [];
  bool _showPlaylists = false;
  
  List<Map<String, dynamic>> _journalNotes = [];
  String _studySubTab = 'journal'; // 'journal', 'verse_notes', 'highlights'
  
  final TextEditingController _journalSearchController = TextEditingController();
  String _journalSearchQuery = '';
  
  bool _isLoading = true;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _journalSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final verses = await _dbService.getFavoritesByType('bible');
    final hymns = await _dbService.getFavoritesByType('hymn');
    final notes = await _dbService.getAllNotesWithVerses();
    final highlights = await _dbService.getAllHighlightsWithVerses();
    final uniqueTags = await _dbService.getAllUniqueTags();
    final playlists = await _dbService.getPlaylists();
    final journal = await _dbService.getAllJournalNotesRaw();

    List<Map<String, dynamic>> taggedVerses = [];
    if (_selectedTagFilter != null) {
      taggedVerses = await _dbService.getVersesByTag(_selectedTagFilter!);
    }

    if (mounted) {
      setState(() {
        _savedVerses = verses;
        _savedHymns = hymns;
        _savedNotes = notes;
        _savedHighlights = highlights;
        _uniqueTags = uniqueTags;
        _taggedVerses = taggedVerses;
        _playlists = playlists;
        _journalNotes = journal;
        _isLoading = false;
      });
    }
  }

  Future<void> _backupData() async {
    try {
      final favorites = await _dbService.getAllFavoritesRaw();
      final highlights = await _dbService.getAllHighlightsRaw();
      final notes = await _dbService.getAllNotesRaw();
      final tags = await _dbService.getAllVerseTagsRaw();
      final history = await _dbService.getAllReadingHistoryRaw();
      final playlists = await _dbService.getAllHymnPlaylistsRaw();
      final playlistItems = await _dbService.getAllHymnPlaylistItemsRaw();
      final journalNotes = await _dbService.getAllJournalNotesRaw();

      final backup = {
        'favorites': favorites,
        'highlights': highlights,
        'notes': notes,
        'tags': tags,
        'history': history,
        'playlists': playlists,
        'playlist_items': playlistItems,
        'journal_notes': journalNotes,
        'backup_time': DateTime.now().millisecondsSinceEpoch,
        'app': 'gospel_hub'
      };

      final jsonStr = jsonEncode(backup);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/gospel_hub_backup.json');
      await file.writeAsString(jsonStr);

      await SharePlus.instance.share(
        ShareParams(
          text: 'Gospel Hub Study Data Backup',
          files: [XFile(file.path)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kubika data byaranze: $e')),
        );
      }
    }
  }

  Future<void> _restoreData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zana data (Restore)'),
        content: const Text(
          'Ibi bigiye gusimbuza inyandiko n\'ibyasomwe byose muri iyi app n\'ibyo wakopije mu gitebo (Clipboard). Urashaka gukomeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Reka'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yego, Zana', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null) {
        throw Exception('Nta makuru wabona mu gitebo (Clipboard is empty)');
      }

      final jsonMap = jsonDecode(clipboardData.text!) as Map<String, dynamic>;
      if (jsonMap['app'] != 'gospel_hub') {
        throw Exception('Aya makuru si aya Gospel Hub backup.');
      }

      final favorites = jsonMap['favorites'] as List<dynamic>? ?? [];
      final highlights = jsonMap['highlights'] as List<dynamic>? ?? [];
      final notes = jsonMap['notes'] as List<dynamic>? ?? [];
      final tags = jsonMap['tags'] as List<dynamic>? ?? [];
      final history = jsonMap['history'] as List<dynamic>? ?? [];
      final playlists = jsonMap['playlists'] as List<dynamic>? ?? [];
      final playlistItems = jsonMap['playlist_items'] as List<dynamic>? ?? [];
      final journalNotes = jsonMap['journal_notes'] as List<dynamic>? ?? [];

      await _dbService.restoreBackup(
        favorites,
        highlights,
        notes,
        tags,
        history,
        playlists,
        playlistItems,
        journalNotes: journalNotes,
      );
      await _loadFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amakuru yatoranyijwe yose yagaruwe neza!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kugarura data byaranze: $e\n(Kora "Kopi" ku makuru ya Backup mbere yo gukanda hano)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.translate('nav_saved'), style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                tooltip: 'Bika amakuru (Backup)',
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: _backupData,
              ),
              IconButton(
                tooltip: 'Garura amakuru (Restore)',
                icon: const Icon(Icons.cloud_download_outlined),
                onPressed: _restoreData,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF60A5FA),
              labelColor: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF60A5FA),
              unselectedLabelColor: Theme.of(context).brightness == Brightness.light ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
              tabs: [
                Tab(text: AppLocalizations.translate('saved_tab_verses')),
                Tab(text: AppLocalizations.translate('saved_tab_hymns')),
                Tab(text: AppLocalizations.translate('saved_tab_study')),
              ],
            ),
          ),
          body: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVersesList(),
                      _buildHymnsList(),
                      _buildStudyNotesList(),
                    ],
                  ),
                ),
          floatingActionButton: _tabController.index == 2 && _studySubTab == 'journal'
              ? FloatingActionButton.extended(
                  onPressed: () => _showJournalEditor(),
                  icon: const Icon(Icons.add),
                  label: Text(localeNotifier.value == 'en' ? 'New Journal' : 'Inyandiko Nshya'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildVersesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_savedVerses.isEmpty) {
      return _buildEmptyState(AppLocalizations.translate('saved_empty_verses'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedVerses.length,
      itemBuilder: (context, index) {
        final verseMap = _savedVerses[index];
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
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await _dbService.removeFavorite('bible', verseMap['id']);
                _loadFavorites();
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

  Widget _buildHymnsList() {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_savedHymns.isEmpty) {
      return _buildEmptyState(AppLocalizations.translate('saved_empty_hymns'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedHymns.length,
      itemBuilder: (context, index) {
        final hymnMap = _savedHymns[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.1),
              child: Text(
                '#${hymnMap['number']}',
                style: TextStyle(color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(hymnMap['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Igitabo: ${hymnMap['book']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await _dbService.removeFavorite('hymn', hymnMap['id']);
                _loadFavorites();
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
          child: _playlists.isEmpty
              ? const Center(child: Text('Nta ntonde z\'indirimbo ziriho.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    final pl = _playlists[index];
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
                            await _dbService.deletePlaylist(pl['id']);
                            _loadFavorites();
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
                await _dbService.createPlaylist(name);
                _loadFavorites();
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
    final hymns = await _dbService.getPlaylistHymns(playlistId);
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
                                await _dbService.removeHymnFromPlaylist(playlistId, song.id!);
                                final updated = await _dbService.getPlaylistHymns(playlistId);
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

  Widget _buildStudyNotesList() {
    return Column(
      children: [
        _buildStudySubNavBar(),
        Expanded(
          child: _buildStudySubTabContent(),
        ),
      ],
    );
  }

  Widget _buildStudySubTabContent() {
    switch (_studySubTab) {
      case 'journal':
        return _buildJournalNotesList();
      case 'verse_notes':
        return _buildVerseNotesList();
      case 'highlights':
        return _buildHighlightsList();
      default:
        return const SizedBox.shrink();
    }
  }


  Widget _buildStudySubNavBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSubTabButton('journal', localeNotifier.value == 'en' ? '📝 Journal' : '📝 Inyandiko'),
          _buildSubTabButton('verse_notes', localeNotifier.value == 'en' ? '📖 Verse Notes' : '📖 Inyandiko z\'Umurongo'),
          _buildSubTabButton('highlights', localeNotifier.value == 'en' ? '🎨 Highlights' : '🎨 Ibimurikirwa'),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(String tab, String label) {
    final isSelected = _studySubTab == tab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _studySubTab = tab),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? const Color(0xFF3B82F6) : Theme.of(context).primaryColor)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected 
                  ? Colors.white 
                  : (isDark ? Colors.grey[350] : const Color(0xFF4B5563)),
            ),
          ),
        ),
      ),
    );
  }

  void _showJournalEditor({Map<String, dynamic>? note}) {
    final titleController = TextEditingController(text: note?['title'] ?? '');
    final contentController = TextEditingController(text: note?['content'] ?? '');
    final isEdit = note != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Kora inyandiko (Edit Note)' : 'Inyandiko nshya (New Note)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              TextField(
                controller: titleController,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Umutwe w\'inyandiko (Title)...',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: contentController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Andika hano (Write note content)...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final content = contentController.text.trim();
                    if (content.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nta kintu cyanditswe!')),
                      );
                      return;
                    }
                    final finalTitle = title.isEmpty ? 'Nta mutwe' : title;
                    if (isEdit) {
                      await _dbService.updateJournalNote(note['id'], finalTitle, content);
                    } else {
                      await _dbService.insertJournalNote(finalTitle, content);
                    }
                    _loadFavorites();
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Bika (Save Note)'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJournalNotesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter notes based on search query
    final filteredNotes = _journalSearchQuery.trim().isEmpty
        ? _journalNotes
        : _journalNotes.where((note) {
            final t = (note['title'] ?? '').toString().toLowerCase();
            final c = (note['content'] ?? '').toString().toLowerCase();
            final q = _journalSearchQuery.toLowerCase();
            return t.contains(q) || c.contains(q);
          }).toList();

    if (_journalNotes.isEmpty) {
      return _buildEmptyState(
        localeNotifier.value == 'en' 
            ? 'Your study journal is empty. Click "+" to start writing.' 
            : 'Nta nyandiko z\'icyigisho ufite. Kanda "+" ngo wandike inyandiko nshya.'
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _journalSearchController,
            onChanged: (val) => setState(() => _journalSearchQuery = val),
            decoration: InputDecoration(
              hintText: localeNotifier.value == 'en' ? 'Search journal...' : 'Shakisha inyandiko...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _journalSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _journalSearchController.clear();
                        setState(() => _journalSearchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredNotes.isEmpty
              ? const Center(child: Text('Nta nyandiko zihuye n\'ibyo ushaka zibonetse.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    final dateStr = DateTime.fromMillisecondsSinceEpoch(note['updated_at'] ?? note['created_at'])
                        .toLocal()
                        .toString()
                        .substring(0, 16);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.1),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showJournalEditor(note: note),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      note['title'] ?? 'Nta mutwe',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                                        onPressed: () {
                                          SharePlus.instance.share(
                                            ShareParams(
                                              text: '${note['title'] ?? ""}\n\n${note['content'] ?? ""}',
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Gusiba inyandiko'),
                                              content: const Text('Urashaka gusiba iyi nyandiko rwose?'),
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
                                            ),
                                          );
                                          if (confirm == true) {
                                            await _dbService.deleteJournalNote(note['id']);
                                            _loadFavorites();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                note['content'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF4B5563),
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                dateStr,
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                              ),
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

  Widget _buildVerseNotesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasNotes = _savedNotes.isNotEmpty;
    final hasTags = _uniqueTags.isNotEmpty;

    if (!hasNotes && !hasTags) {
      return _buildEmptyState(AppLocalizations.translate('saved_empty_study'));
    }

    return Column(
      children: [
        if (hasTags)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _uniqueTags.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _selectedTagFilter == null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: const Text('Zose (All)', style: TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedTagFilter = null;
                        });
                        _loadFavorites();
                      },
                    ),
                  );
                }

                final tag = _uniqueTags[index - 1];
                final isSelected = _selectedTagFilter == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTagFilter = selected ? tag : null;
                      });
                      _loadFavorites();
                    },
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: _selectedTagFilter != null
              ? _buildTaggedVersesList()
              : _savedNotes.isEmpty
                  ? _buildEmptyState(
                      localeNotifier.value == 'en' 
                          ? 'No verse notes saved. Tap and hold a verse in reader to add notes.' 
                          : 'Nta nyandiko z\'umurongo ufite.'
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: _savedNotes.map((note) {
                        final bookObj = BibleBook.getByNumber(note['book']);
                        final refStr = '${bookObj.name} ${note['chapter']}:${note['verse']}';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.1),
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              final parentState = context.findAncestorStateOfType<HomeScreenState>();
                              parentState?.navigateToBibleVerse(bookObj, note['chapter'], note['verse']);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          refStr,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                                            onPressed: () {
                                              SharePlus.instance.share(
                                                ShareParams(
                                                  text: 'Inyandiko z\'umurongo kuri $refStr:\n"${note['text']}"\n\nInyandiko: ${note['note_content']}',
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () async {
                                              await _dbService.removeNote(note['id']);
                                              _loadFavorites();
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    note['note_content'],
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF242424) : const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF333333) : const Color(0xFFF3F4F6),
                                      ),
                                    ),
                                    child: Text(
                                      note['text'],
                                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, fontFamily: 'serif', height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildHighlightsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_savedHighlights.isEmpty) {
      return _buildEmptyState(
        localeNotifier.value == 'en' 
            ? 'No highlights saved. Tap a verse in reader to highlight it.' 
            : 'Nta bintu bimuritswe ufite.'
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedHighlights.length,
      itemBuilder: (context, index) {
        final hl = _savedHighlights[index];
        final bookObj = BibleBook.getByNumber(hl['book']);
        final refStr = '${bookObj.name} ${hl['chapter']}:${hl['verse']}';
        final highlightColor = _highlightColors[hl['color_index']];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            onTap: () {
              final parentState = context.findAncestorStateOfType<HomeScreenState>();
              parentState?.navigateToBibleVerse(bookObj, hl['chapter'], hl['verse']);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: highlightColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              refStr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                            onPressed: () {
                              SharePlus.instance.share(
                                ShareParams(
                                  text: '"${hl['text']}"\n\n— $refStr',
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () async {
                              await _dbService.removeHighlight(hl['id']);
                              _loadFavorites();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hl['text'],
                    style: const TextStyle(fontSize: 14, fontFamily: 'serif', height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaggedVersesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_taggedVerses.isEmpty) {
      return _buildEmptyState('Nta mirongo ifite iki kimenyetso.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _taggedVerses.length,
      itemBuilder: (context, index) {
        final item = _taggedVerses[index];
        final bookObj = BibleBook.getByNumber(item['book']);
        final refStr = '${bookObj.name} ${item['chapter']}:${item['verse']}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              item['text'],
              style: const TextStyle(fontSize: 14, fontFamily: 'serif', height: 1.5),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Row(
                children: [
                  Text(
                    refStr,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item['tag_name'],
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await _dbService.removeVerseTag(item['verse_id'] ?? item['id'], item['tag_name']);
                _loadFavorites();
              },
            ),
            onTap: () {
              final parentState = context.findAncestorStateOfType<HomeScreenState>();
              parentState?.navigateToBibleVerse(bookObj, item['chapter'], item['verse']);
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
          Text(
            text,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}