import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const DashboardTab(),
      BibleReaderScreen(key: _bibleReaderKey),
      const HymnsScreen(),
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: _tabs[_currentTabIndex],
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
                                // Simple share stub
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
            const SizedBox(height: 24),

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final verses = await _dbService.getFavoritesByType('bible');
    final hymns = await _dbService.getFavoritesByType('hymn');
    if (mounted) {
      setState(() {
        _savedVerses = verses;
        _savedHymns = hymns;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ibyatoranyijwe', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Imirongo'),
            Tab(text: 'Indirimbo'),
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
              // Open hymn detail screen
              final hymnObj = Hymn.fromMap(hymnMap);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HymnDetailModal(hymn: hymnObj),
                ),
              );
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