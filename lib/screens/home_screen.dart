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
import '../widgets/saved/saved_verses_tab.dart';
import '../widgets/saved/saved_hymns_tab.dart';
import '../widgets/saved/saved_study_tab.dart';

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
    // Defer heavy widget sync until after the first frame is painted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWidgetDataIfNeeded();
    });
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

  /// Only re-syncs widget data when the date changes (not every launch).
  void _syncWidgetDataIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      final lastSync = prefs.getString('widget_last_sync_date');
      if (lastSync == today) return; // Already synced today
      await WidgetService.syncWidgetData();
      await prefs.setString('widget_last_sync_date', today);
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
  
  List<Map<String, dynamic>> _playlists = [];
  
  List<Map<String, dynamic>> _journalNotes = [];
  String _studySubTab = 'journal'; // 'journal', 'verse_notes', 'highlights'
  
  final TextEditingController _journalSearchController = TextEditingController();
  
  bool _isLoading = true;


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

    // Run all queries in parallel instead of sequentially
    final results = await Future.wait([
      _dbService.getFavoritesByType('bible'),
      _dbService.getFavoritesByType('hymn'),
      _dbService.getAllNotesWithVerses(),
      _dbService.getAllHighlightsWithVerses(),
      _dbService.getAllUniqueTags(),
      _dbService.getPlaylists(),
      _dbService.getAllJournalNotesRaw(),
    ]);

    if (mounted) {
      setState(() {
        _savedVerses = results[0] as List<Map<String, dynamic>>;
        _savedHymns = results[1] as List<Map<String, dynamic>>;
        _savedNotes = results[2] as List<Map<String, dynamic>>;
        _savedHighlights = results[3] as List<Map<String, dynamic>>;
        _uniqueTags = results[4] as List<String>;
        _playlists = results[5] as List<Map<String, dynamic>>;
        _journalNotes = results[6] as List<Map<String, dynamic>>;
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
                      SavedVersesTab(
                        savedVerses: _savedVerses,
                        dbService: _dbService,
                        onDataChanged: _loadFavorites,
                      ),
                      SavedHymnsTab(
                        savedHymns: _savedHymns,
                        playlists: _playlists,
                        dbService: _dbService,
                        onDataChanged: _loadFavorites,
                      ),
                      SavedStudyTab(
                        journalNotes: _journalNotes,
                        savedNotes: _savedNotes,
                        savedHighlights: _savedHighlights,
                        uniqueTags: _uniqueTags,
                        dbService: _dbService,
                        onDataChanged: _loadFavorites,
                        initialStudySubTab: _studySubTab,
                        onStudySubTabChanged: (val) => setState(() => _studySubTab = val),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

}
