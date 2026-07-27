import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../models/hymn.dart';
import '../services/app_localizations.dart';
import '../widgets/book_page_fold.dart';

class HymnsScreen extends StatefulWidget {
  const HymnsScreen({super.key});

  @override
  State<HymnsScreen> createState() => HymnsScreenState();
}

class HymnsScreenState extends State<HymnsScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  Hymn? _selectedHymn;
  late TabController _tabController;

  final ScrollController _gushimishaScrollController = ScrollController();
  final ScrollController _agakizaScrollController = ScrollController();

  // HUD and Beaming variables
  String? _hudText;
  bool _showHUDWidget = false;
  Timer? _hudTimer;

  int? _beamedGushimishaIndex;
  int? _beamedAgakizaIndex;
  Timer? _beamTimer;

  // Active touch coordinate for fast-scroll magnification
  double? _activeTouchY;
  bool _isDraggingFastScroll = false;

  // Preloaded caching
  bool _isPreloading = true;
  List<Hymn> _allGushimishaHymns = [];
  List<Hymn> _allAgakizaHymns = [];
  List<String> _gushimishaCategories = [];
  List<String> _agakizaCategories = [];

  // Filtered lists
  List<Hymn> _filteredGushimishaList = [];
  List<Hymn> _filteredAgakizaList = [];

  // Selections
  String? _selectedGushimishaCategory;
  String? _selectedAgakizaCategory;

  // Navigation state:
  // 0: INDIRIMBO Book card list (first view)
  // 1: Tabbed hymns list (Gushimisha and Agakiza tabs)
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
    _gushimishaScrollController.addListener(_onScrollUpdated);
    _agakizaScrollController.addListener(_onScrollUpdated);
    _preloadAllHymns();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _gushimishaScrollController.removeListener(_onScrollUpdated);
    _gushimishaScrollController.dispose();
    _agakizaScrollController.removeListener(_onScrollUpdated);
    _agakizaScrollController.dispose();
    _hudTimer?.cancel();
    _beamTimer?.cancel();
    super.dispose();
  }

  void _onScrollUpdated() {
    if (!_isDraggingFastScroll) {
      setState(() {});
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        // Clear search when changing tabs
        if (_isSearching) {
          _isSearching = false;
          _searchController.clear();
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

      if (mounted) {
        setState(() {
          _allGushimishaHymns = gList;
          _gushimishaCategories = gCats;
          _allAgakizaHymns = aList;
          _agakizaCategories = aCats;
          _isPreloading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      print('Error preloading hymns: $e');
      if (mounted) {
        setState(() => _isPreloading = false);
      }
    }
  }

  void selectHymn(Hymn hymn) {
    setState(() {
      _selectedHymn = hymn;
      _currentView = 1;
      final targetIndex = hymn.book == 'Gushimisha' ? 0 : 1;
      if (_tabController.index != targetIndex) {
        _tabController.index = targetIndex;
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
    final query = _searchController.text.toLowerCase().trim();

    // 1. Filter Gushimisha
    List<Hymn> tempG = _allGushimishaHymns;
    if (_selectedGushimishaCategory != null) {
      tempG = tempG.where((hymn) => hymn.category == _selectedGushimishaCategory).toList();
    }
    if (query.isNotEmpty) {
      tempG = _filterListByQuery(tempG, query);
    }

    // 2. Filter Agakiza
    List<Hymn> tempA = _allAgakizaHymns;
    if (_selectedAgakizaCategory != null) {
      tempA = tempA.where((hymn) => hymn.category == _selectedAgakizaCategory).toList();
    }
    if (query.isNotEmpty) {
      tempA = _filterListByQuery(tempA, query);
    }

    setState(() {
      _filteredGushimishaList = tempG;
      _filteredAgakizaList = tempA;
    });
  }

  List<Hymn> _filterListByQuery(List<Hymn> list, String query) {
    return list.where((hymn) {
      final matchesNum = hymn.number.toString() == query;
      final matchesTitle = hymn.title.toLowerCase().contains(query);
      final matchesLyrics = hymn.lyrics.any(
        (block) => block.lines.any((line) => line.toLowerCase().contains(query))
      );
      return matchesNum || matchesTitle || matchesLyrics;
    }).toList();
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
            });
          }
        },
        child: HymnDetailModal(
          hymn: _selectedHymn!,
          onBack: () => setState(() => _selectedHymn = null),
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
      canPop: _currentView == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() {
            _currentView = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _currentView == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: () {
                    setState(() {
                      _currentView = 0;
                    });
                  },
                )
              : null,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.translate('hymns_search_hint'),
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  autofocus: true,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                )
              : Text(
                  _currentView == 1 ? 'INDIRIMBO' : AppLocalizations.translate('hymns_books_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
          actions: [
            if (_currentView == 1)
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                    }
                  });
                },
              ),
          ],
          bottom: _currentView == 0
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
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildHymnsList(isDark, true),
                  _buildHymnsList(isDark, false),
                ],
              ),
      ),
    );
  }

  Widget _buildHymnBooksList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              setState(() {
                _currentView = 1;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xFF1A365D), const Color(0xFF1B1D1B)]
                      : [const Color(0xFFEBF3FF), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.library_books,
                      color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INDIRIMBO',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Indirimbo zo Gushimisha Imana n\'Agakiza',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ],
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
          child: list.isEmpty
              ? const Center(
                  child: Text('Nta ndirimbo yabonetse yujuje ibi bintu.', style: TextStyle(color: Colors.grey)),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      controller: isGushimisha ? _gushimishaScrollController : _agakizaScrollController,
                      padding: const EdgeInsets.only(left: 16, right: 56, top: 8, bottom: 8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final hymn = list[index];
                        final isBeamed = isGushimisha 
                            ? index == _beamedGushimishaIndex 
                            : index == _beamedAgakizaIndex;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: isBeamed ? 4 : 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            leading: CircleAvatar(
                              backgroundColor: (isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor).withValues(alpha: 0.1),
                              child: Text(
                                '${hymn.number}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              hymn.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: Text(
                              hymn.category,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
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
                      child: _buildVerticalIndexer(context, list, isGushimisha),
                    ),
                    if (_showHUDWidget && _hudText != null)
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
                                _hudText!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
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

  Widget _buildVerticalIndexer(BuildContext context, List<Hymn> list, bool isGushimisha) {
    if (list.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = isGushimisha ? _gushimishaScrollController : _agakizaScrollController;

    // Calculate current scroll progress if scroll controller has clients
    double scrollPercent = 0.0;
    if (controller.hasClients && controller.position.maxScrollExtent > 0) {
      scrollPercent = (controller.offset / controller.position.maxScrollExtent).clamp(0.0, 1.0);
    }

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
          if (controller.hasClients) {
            // Compute offset based on targetIndex
            // Each card is roughly 80.0 pixels tall
            final itemScrollOffset = targetIndex * 80.0;
            final maxScroll = controller.position.maxScrollExtent;
            final targetOffset = itemScrollOffset.clamp(0.0, maxScroll);
            controller.jumpTo(targetOffset);
          }

          // Beam highlight effect
          setState(() {
            if (isGushimisha) {
              _beamedGushimishaIndex = targetIndex;
            } else {
              _beamedAgakizaIndex = targetIndex;
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
  }
}

class HymnDetailModal extends StatefulWidget {
  final Hymn hymn;
  final VoidCallback? onBack;

  const HymnDetailModal({super.key, required this.hymn, this.onBack});

  @override
  State<HymnDetailModal> createState() => _HymnDetailModalState();
}

class _HymnDetailModalState extends State<HymnDetailModal> {
  final DatabaseService _dbService = DatabaseService();
  late Hymn _currentHymn;
  bool _isFav = false;
  double _fontSize = 16.0;
  bool _canTurnForward = true;
  bool _canTurnBackward = false;

  @override
  void initState() {
    super.initState();
    _currentHymn = widget.hymn;
    _canTurnBackward = _currentHymn.number > 1;
    _checkFavorite();
    _refreshTurnAvailability();
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
    setState(() => _currentHymn = target);
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

  Widget _buildHymnBody(
    Hymn hymn, {
    required bool isDark,
    required Color primaryColor,
    required bool scrollable,
  }) {
    return SingleChildScrollView(
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  '${hymn.number}. ${hymn.title}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF60A5FA) : primaryColor,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (hymn.category.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF60A5FA) : primaryColor)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hymn.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF60A5FA) : primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: hymn.lyrics.length,
            itemBuilder: (context, index) {
              final block = hymn.lyrics[index];
              final isChorus = block.type == 'chorus';

              return Container(
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Text(
                        isChorus ? 'Ch.' : '${block.number ?? ""}',
                        style: TextStyle(
                          fontSize: _fontSize - 1,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? const Color(0xFF60A5FA) : primaryColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: block.lines.map((line) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
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

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: widget.onBack,
              )
            : null,
        title: Text('${_currentHymn.book} - indirimbo ya ${_currentHymn.number}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_size),
            onPressed: _showSettingsBottomSheet,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'playlist') {
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
                // Copy all lyrics as plain text
                final buffer = StringBuffer();
                buffer.writeln('${_currentHymn.number}. ${_currentHymn.title} (${_currentHymn.book})\n');
                for (var block in _currentHymn.lyrics) {
                  if (block.type == 'chorus') {
                    buffer.writeln('[Chorus/Gusubiramo]');
                  } else {
                    buffer.writeln('[Verse ${block.number}]');
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
      body: BookPageFold(
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
        ),
      ),
    );
  }
}