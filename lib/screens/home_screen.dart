import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'bible_reader_screen.dart';
import 'hymns_screen.dart';
import '../services/database_service.dart';
import '../models/hymn.dart';
import '../models/bible_book.dart';
import '../main.dart';
import '../services/app_state_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  final GlobalKey<BibleReaderScreenState> _bibleReaderKey = GlobalKey<BibleReaderScreenState>();
  final GlobalKey<HymnsScreenState> _hymnsScreenKey = GlobalKey<HymnsScreenState>();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const DashboardTab(),
      BibleReaderScreen(key: _bibleReaderKey),
      HymnsScreen(key: _hymnsScreenKey),
      const SavedItemsTab(),
    ];
  }

  void navigateToBibleVerse(BibleBook book, int chapter, int verse) {
    setState(() {
      _currentTabIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bibleReaderKey.currentState?.jumpToVerse(book, chapter, verse);
    });
  }

  void navigateToHymn(Hymn hymn) {
    setState(() {
      _currentTabIndex = 2; // Switch to Hymns tab
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hymnsScreenKey.currentState?.selectHymn(hymn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: IndexedStack(
        index: _currentTabIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade500,
          backgroundColor: Theme.of(context).brightness == Brightness.light 
              ? Colors.white 
              : const Color(0xFF121212),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Ahabanza',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Bibiliya',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note_outlined),
              activeIcon: Icon(Icons.music_note),
              label: 'Indirimbo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Ibyatoranyijwe',
            ),
          ],
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

  // Static daily verses in Kinyarwanda
  static const List<Map<String, String>> _dailyVerses = [
    {
      'ref': 'Yohana 3:16',
      'text': 'Kuko Imana yakunze abari mu isi cyane, byatumye itanga Umwana wayo w\'ikinege, ngo umwizera wese atarimbuka, ahubwo ahabwe ubugingo buhoraho.'
    },
    {
      'ref': 'Yosuwa 1:9',
      'text': 'Mbese sinabigutegetse? Komeza umutima ube intwari, ntugatinye kandi ntuguke umutima, kuko Uwiteka Imana yawe iri kumwe nawe mu byo uzakora byose.'
    },
    {
      'ref': 'Zaburi 23:1',
      'text': 'Uwiteka ni Umwungeri wanjye, ntacyo nzakena.'
    },
    {
      'ref': 'Abaroma 8:28',
      'text': 'Kandi tuzi yuko ku bakunda Imana byose bafatanyiriza hamwe kubazanira ibyiza, ari bo bahamagawe nk\'uko umugambi wayo uri.'
    },
    {
      'ref': 'Imigani 3:5-6',
      'text': 'Wiringire Uwiteka n\'umutima wawe wose, kandi ntiwishingikirize ku buhanga bwawe. Mu nzira zawe zose ujye umwemera, na we azagorora inzira zawe.'
    },
    {
      'ref': 'Abafilipi 4:13',
      'text': 'Nshobozwa byose n\'umpa imbaraga.'
    },
  ];

  Map<String, String> get _todayVerse {
    final dayIndex = DateTime.now().day % _dailyVerses.length;
    return _dailyVerses[dayIndex];
  }

  void _navigateToVerse(String ref) {
    try {
      final lastSpaceIndex = ref.lastIndexOf(' ');
      if (lastSpaceIndex == -1) return;

      final bookName = ref.substring(0, lastSpaceIndex).trim();
      final rest = ref.substring(lastSpaceIndex + 1).trim();

      final colonIndex = rest.indexOf(':');
      if (colonIndex == -1) return;

      final chapterStr = rest.substring(0, colonIndex);
      var verseStr = rest.substring(colonIndex + 1);

      final hyphenIndex = verseStr.indexOf('-');
      if (hyphenIndex != -1) {
        verseStr = verseStr.substring(0, hyphenIndex);
      }

      final chapter = int.tryParse(chapterStr);
      final verse = int.tryParse(verseStr);

      if (chapter == null || verse == null) return;

      final bookObj = BibleBook.allBooks.firstWhere(
        (b) => b.name.toLowerCase() == bookName.toLowerCase(),
        orElse: () => BibleBook.allBooks.firstWhere(
          (b) => b.name.toLowerCase().contains(bookName.toLowerCase()),
          orElse: () => BibleBook.allBooks.first,
        ),
      );

      final parentState = context.findAncestorStateOfType<_HomeScreenState>();
      parentState?.navigateToBibleVerse(bookObj, chapter, verse);
    } catch (e) {
      print('Error parsing reference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            Text(
              'Gospel Hub',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: isDark ? 'Koresha umweru' : 'Koresha umukara',
            onPressed: () async {
              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
              themeNotifier.value = newMode;
              await AppStateService.setDarkMode(newMode == ThemeMode.dark);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Verse Card
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _navigateToVerse(_todayVerse['ref']!),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                          ? [const Color(0xFF1A365D), const Color(0xFF101210)]
                          : [const Color(0xFFEBF3FF), Colors.white],
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
                          Icon(Icons.auto_awesome, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Umurongo w\'Umunsi',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '"${_todayVerse['text']}"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _todayVerse['ref']!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_outlined, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                    text: '${_todayVerse['text']} (${_todayVerse['ref']})'
                                  ));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Umusaruro wakopijwe!'))
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_outlined, size: 20),
                                onPressed: () {
                                  SharePlus.instance.share(
                                    ShareParams(
                                      text: '"${_todayVerse['text']}"\n\n— ${_todayVerse['ref']}',
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
            ),
            const SizedBox(height: 24),

            // Devotional Habit Statistics Card
            if (!_loadingStats) ...[
              Text(
                'Ibikorwa byawe by\'isengesho (My Devotion)',
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
                            const Text('Umunsi Uhoraho', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Text('(Daily Streak)', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                                Icon(Icons.check_circle_outline, color: primaryColor, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  '${_stats['total_chapters'] ?? 0}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Ibyo Wasomye', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Text('(Chapters Read)', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                const Text(
                  'Aho ugeze usoma (Recently Read)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
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
                        leading: Icon(Icons.history, color: primaryColor, size: 20),
                        title: Text(
                          '${bookObj.name} Igice cya ${item['chapter']}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () {
                          final parentState = context.findAncestorStateOfType<_HomeScreenState>();
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
              'Ibice by\'Ijambo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Card list for main features
            _MenuCard(
              title: 'Bibiliya Yera',
              subtitle: 'Isezerano rya Kera n\'Iryo Kabiri mu Kinyarwanda (2001)',
              icon: Icons.menu_book,
              color: primaryColor,
              onTap: () {
                // Switch to Bible tab
                final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                parentState?.setState(() {
                  parentState._currentTabIndex = 1;
                });
              },
            ),
            const SizedBox(height: 12),
            _MenuCard(
              title: 'Indirimbo zo Gushimisha n\'Agakiza',
              subtitle: 'Indirimbo 546 z\'Agakiza n\'iz\'Imana zo Gushimisha',
              icon: Icons.music_note,
              color: const Color(0xFF00A8FF),
              onTap: () {
                // Switch to Hymns tab
                final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                parentState?.setState(() {
                  parentState._currentTabIndex = 2;
                });
              },
            ),
            const SizedBox(height: 12),
            _MenuCard(
              title: 'Ibyatoranyijwe',
              subtitle: 'Gushaka imirongo n\'indirimbo wabitse',
              icon: Icons.favorite,
              color: Colors.red.shade600,
              onTap: () {
                // Switch to Saved tab
                final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                parentState?.setState(() {
                  parentState._currentTabIndex = 3;
                });
              },
            ),
          ],
        ),
      ),
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
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final verses = await _dbService.getFavoritesByType('bible');
    final hymns = await _dbService.getFavoritesByType('hymn');
    final notes = await _dbService.getAllNotesWithVerses();
    final highlights = await _dbService.getAllHighlightsWithVerses();
    final uniqueTags = await _dbService.getAllUniqueTags();
    final playlists = await _dbService.getPlaylists();

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

      final backup = {
        'favorites': favorites,
        'highlights': highlights,
        'notes': notes,
        'tags': tags,
        'history': history,
        'playlists': playlists,
        'playlist_items': playlistItems,
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

      await _dbService.restoreBackup(favorites, highlights, notes, tags, history, playlists, playlistItems);
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
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ibyatoranyijwe', style: TextStyle(fontWeight: FontWeight.bold)),
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
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Imirongo'),
            Tab(text: 'Indirimbo'),
            Tab(text: 'Icyigisho'),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVersesList(),
                _buildHymnsList(),
                _buildStudyNotesList(),
              ],
            ),
    );
  }

  Widget _buildVersesList() {
    if (_savedVerses.isEmpty) {
      return _buildEmptyState('Nta murongo w\'Ijambo watoranyijwe urabikwa.');
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
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
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
              final parentState = context.findAncestorStateOfType<_HomeScreenState>();
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
    if (_savedHymns.isEmpty) {
      return _buildEmptyState('Nta ndirimbo yatoranyijwe urabikwa.');
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
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                '#${hymnMap['number']}',
                style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
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
              final parentState = context.findAncestorStateOfType<_HomeScreenState>();
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
                              final parentState = context.findAncestorStateOfType<_HomeScreenState>();
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
    final hasHighlights = _savedHighlights.isNotEmpty;
    final hasNotes = _savedNotes.isNotEmpty;
    final hasTags = _uniqueTags.isNotEmpty;

    if (!hasHighlights && !hasNotes && !hasTags) {
      return _buildEmptyState('Nta nyandiko cyangwa bimurikirwa bikabikwa.');
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (hasNotes) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Inyandiko z\'Icyigisho (${_savedNotes.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      ..._savedNotes.map((note) {
                        final bookObj = BibleBook.getByNumber(note['book']);
                        final refStr = '${bookObj.name} ${note['chapter']}:${note['verse']}';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              note['note_content'],
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Umurongo: "${note['text']}"',
                                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, fontFamily: 'serif'),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    refStr,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                await _dbService.removeNote(note['id']);
                                _loadFavorites();
                              },
                            ),
                            onTap: () {
                              final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                              parentState?.navigateToBibleVerse(bookObj, note['chapter'], note['verse']);
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    if (hasHighlights) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Ibimurikirwa (Highlights) (${_savedHighlights.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      ..._savedHighlights.map((hl) {
                        final bookObj = BibleBook.getByNumber(hl['book']);
                        final refStr = '${bookObj.name} ${hl['chapter']}:${hl['verse']}';
                        final highlightColor = _highlightColors[hl['color_index']];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 16,
                              height: 36,
                              decoration: BoxDecoration(
                                color: highlightColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            title: Text(
                              hl['text'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontFamily: 'serif'),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                refStr,
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 12),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                await _dbService.removeHighlight(hl['id']);
                                _loadFavorites();
                              },
                            ),
                            onTap: () {
                              final parentState = context.findAncestorStateOfType<_HomeScreenState>();
                              parentState?.navigateToBibleVerse(bookObj, hl['chapter'], hl['verse']);
                            },
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTaggedVersesList() {
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item['tag_name'],
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
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
              final parentState = context.findAncestorStateOfType<_HomeScreenState>();
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