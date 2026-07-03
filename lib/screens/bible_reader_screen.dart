import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../models/bible_verse.dart';
import '../models/bible_book.dart';

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
    _loadVerses();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVerses() async {
    setState(() => _isLoading = true);
    try {
      final verses = await _dbService.getChapterVerses(_selectedBook.bookNumber, _selectedChapter);
      if (mounted) {
        setState(() {
          _verses = verses;
          _verseKeys = List.generate(verses.length, (index) => GlobalKey());
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
      final textLength = v.text.length;
      final charsPerLine = 40.0 * (17.0 / _fontSize);
      final lines = (textLength / charsPerLine).ceil();
      final verseHeight = lines * (_fontSize * 1.6) + 24.0;
      estimatedOffset += verseHeight;
    }

    // 2. Jump close so ListView builds it
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(estimatedOffset);
    }

    // 3. Precise scroll to context in the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    return const Color(0xFFFAFBFB);
  }

  Color _getTextColor(bool isDark) {
    final activeMode = _getActiveThemeMode(isDark);
    if (activeMode == 'Dark') return Colors.grey.shade300;
    if (activeMode == 'Warm') return const Color(0xFF4C3E26);
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Shaka umurongo...',
                  border: InputBorder.none,
                ),
                onChanged: _searchBible,
                autofocus: true,
              )
            : Text(
                '${_selectedBook.name} $_selectedChapter',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
            IconButton(
              icon: const Icon(Icons.format_size),
              onPressed: _showSettingsBottomSheet,
            ),
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: _showBookSelectorModal,
            ),
          ]
        ],
      ),
      body: _isSearching 
          ? _buildSearchResultsList()
          : _buildReaderView(primaryColor, isDark),
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
            title: Text(
              verse.text,
              style: const TextStyle(fontSize: 15, fontFamily: 'serif', height: 1.4),
            ),
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
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < 0) {
                  _nextChapter();
                } else if (details.primaryVelocity! > 0) {
                  _prevChapter();
                }
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: _verses.length,
                itemBuilder: (context, index) {
                  final verse = _verses[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: VerseItem(
                      key: _verseKeys[index],
                      verse: verse,
                      fontSize: _fontSize,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      isHighlighted: _targetVerse == verse.verse,
                      onTap: () => _showVerseActionsModal(verse),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161616) : Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: _prevChapter,
                ),
                Text(
                  '${_selectedBook.name} $_selectedChapter',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 20),
                  onPressed: _nextChapter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVerseActionsModal(BibleVerse verse) async {
    final isFav = await _dbService.isFavorite('bible', verse.id!);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_selectedBook.name} ${verse.chapter}:${verse.verse}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                verse.text,
                style: const TextStyle(fontStyle: FontStyle.italic, fontFamily: 'serif', fontSize: 15),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ActionButton(
                    icon: isFav ? Icons.favorite : Icons.favorite_border,
                    label: isFav ? 'Kuraho' : 'Bika',
                    color: isFav ? Colors.red : Colors.grey.shade700,
                    onTap: () async {
                      if (isFav) {
                        await _dbService.removeFavorite('bible', verse.id!);
                      } else {
                        await _dbService.addFavorite('bible', verse.id!);
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isFav ? 'Mukuraho!' : 'Yabitswe mu Byatoranyijwe!'))
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.copy,
                    label: 'Kopi',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '${verse.text} (${_selectedBook.name} ${verse.chapter}:${verse.verse})'));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Umusaruro wakopijwe!'))
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
                  const Text('Ibipimo by\'Inyandiko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  const Text('Ibikoresho by\'Umwanya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ThemeButton(
                        label: 'Umweru',
                        selected: _getActiveThemeMode(isDark) == 'Light',
                        bgColor: Colors.white,
                        textColor: Colors.black87,
                        onTap: () {
                          setModalState(() => _customThemeMode = 'Light');
                          setState(() => _customThemeMode = 'Light');
                        },
                      ),
                      _ThemeButton(
                        label: 'Umutuku',
                        selected: _getActiveThemeMode(isDark) == 'Warm',
                        bgColor: const Color(0xFFF7F2E8),
                        textColor: const Color(0xFF4C3E26),
                        onTap: () {
                          setModalState(() => _customThemeMode = 'Warm');
                          setState(() => _customThemeMode = 'Warm');
                        },
                      ),
                      _ThemeButton(
                        label: 'Umukara',
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
                    tabs: const [
                      Tab(text: 'Isezerano rya Kera'),
                      Tab(text: 'Isezerano Rishya'),
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
                book.name,
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
  final VoidCallback onTap;

  const VerseItem({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.textColor,
    required this.primaryColor,
    required this.isHighlighted,
    required this.onTap,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isHighlighted 
                ? widget.primaryColor.withValues(alpha: _animation.value)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: child,
        );
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
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
              TextSpan(text: widget.verse.text),
            ],
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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