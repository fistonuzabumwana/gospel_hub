import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../models/hymn.dart';

class HymnsScreen extends StatefulWidget {
  const HymnsScreen({super.key});

  @override
  State<HymnsScreen> createState() => _HymnsScreenState();
}

class _HymnsScreenState extends State<HymnsScreen> {
  final DatabaseService _dbService = DatabaseService();

  // Navigation states:
  // 0: Hymn Books List (cards like INDIRIMBO)
  // 1: Sub-books Selector (Gushimisha or Agakiza)
  // 2: Song List inside Selected Book
  int _currentView = 0;
  String _selectedBookName = ''; // 'Gushimisha' or 'Agakiza'

  List<Hymn> _hymnsList = [];
  List<Hymn> _filteredHymnsList = [];
  bool _isLoading = false;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredHymnsList = _hymnsList;
      });
      return;
    }

    setState(() {
      _filteredHymnsList = _hymnsList.where((hymn) {
        final matchesNum = hymn.number.toString() == query;
        final matchesTitle = hymn.title.toLowerCase().contains(query);
        final matchesCategory = hymn.category.toLowerCase().contains(query);
        final matchesLyrics = hymn.lyrics.any(
          (block) => block.lines.any((line) => line.toLowerCase().contains(query))
        );
        return matchesNum || matchesTitle || matchesCategory || matchesLyrics;
      }).toList();
    });
  }

  Future<void> _loadHymns(String bookName) async {
    setState(() {
      _isLoading = true;
      _selectedBookName = bookName;
      _currentView = 2;
    });

    try {
      final list = await _dbService.getHymnsByBook(bookName);
      if (mounted) {
        setState(() {
          _hymnsList = list;
          _filteredHymnsList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading hymns: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goBack() {
    setState(() {
      if (_currentView == 2) {
        _currentView = 1;
        _hymnsList = [];
        _filteredHymnsList = [];
        _searchController.clear();
        _isSearching = false;
      } else if (_currentView == 1) {
        _currentView = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _currentView == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _currentView > 0 
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: _goBack,
                )
              : null,
          title: _isSearching 
              ? TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Shaka indirimbo (izina, numero cyangwa amagambo)...',
                    border: InputBorder.none,
                  ),
                  autofocus: true,
                  style: const TextStyle(fontSize: 16),
                )
              : Text(
                  _currentView == 2 ? _selectedBookName : 'Ibitabo by\'Indirimbo',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
          actions: [
            if (_currentView == 2)
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
        ),
        body: _buildCurrentView(isDark),
      ),
    );
  }

  Widget _buildCurrentView(bool isDark) {
    if (_currentView == 0) {
      return _buildHymnBooksList(isDark);
    }
    if (_currentView == 1) {
      return _buildSubBooksSelector(isDark);
    }
    return _buildHymnsList(isDark);
  }

  // 1. First View: List of Hymnbooks (cards)
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
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.library_books,
                      color: Theme.of(context).primaryColor,
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

  // 2. Second View: Sub-books Selector (Gushimisha or Agakiza)
  Widget _buildSubBooksSelector(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubBookCard(
          title: 'Indirimbo zo Gushimisha',
          subtitle: 'Ibitabo bihabwa Imana (1 - 436)',
          count: '436 indirimbo',
          color: Theme.of(context).primaryColor,
          isDark: isDark,
          onTap: () => _loadHymns('Gushimisha'),
        ),
        const SizedBox(height: 16),
        _buildSubBookCard(
          title: 'Indirimbo z\'Agakiza',
          subtitle: 'Ibitabo by\'Agakiza (1 - 110)',
          count: '110 indirimbo',
          color: const Color(0xFF00A8FF),
          isDark: isDark,
          onTap: () => _loadHymns('Agakiza'),
        ),
      ],
    );
  }

  Widget _buildSubBookCard({
    required String title,
    required String subtitle,
    required String count,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.music_note, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        count,
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
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

  // 3. Third View: Hymns Grid/List inside selected Book
  Widget _buildHymnsList(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredHymnsList.isEmpty) {
      return const Center(
        child: Text('Nta ndirimbo yabonetse yujuje ibi bintu.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredHymnsList.length,
      itemBuilder: (context, index) {
        final hymn = _filteredHymnsList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0.5,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                '${hymn.number}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              hymn.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HymnDetailModal(hymn: hymn),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class HymnDetailModal extends StatefulWidget {
  final Hymn hymn;

  const HymnDetailModal({super.key, required this.hymn});

  @override
  State<HymnDetailModal> createState() => _HymnDetailModalState();
}

class _HymnDetailModalState extends State<HymnDetailModal> {
  final DatabaseService _dbService = DatabaseService();
  bool _isFav = false;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final status = await _dbService.isFavorite('hymn', widget.hymn.id!);
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
                  const Text(
                    'Ibipimo by\'Inyandiko',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.hymn.book} - indirimbo ya ${widget.hymn.number}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_size),
            onPressed: _showSettingsBottomSheet,
          ),
          IconButton(
            icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border, color: _isFav ? Colors.red : null),
            onPressed: () async {
              if (_isFav) {
                await _dbService.removeFavorite('hymn', widget.hymn.id!);
              } else {
                await _dbService.addFavorite('hymn', widget.hymn.id!);
              }
              setState(() => _isFav = !_isFav);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_isFav ? 'Yabitswe mu Byatoranyijwe!' : 'Mukuraho!'))
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              // Copy all lyrics as plain text
              final buffer = StringBuffer();
              buffer.writeln('${widget.hymn.title} (${widget.hymn.book} #${widget.hymn.number})\n');
              for (var block in widget.hymn.lyrics) {
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
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    widget.hymn.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.hymn.category.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.hymn.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Lyrics block list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.hymn.lyrics.length,
              itemBuilder: (context, index) {
                final block = widget.hymn.lyrics[index];
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
                            color: primaryColor.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        )
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left label column: Verse number or Ref/Chorus badge
                      Container(
                        width: 44,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Text(
                          isChorus ? 'Ch.' : '${block.number ?? ""}',
                          style: TextStyle(
                            fontSize: _fontSize - 1,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      // Lines column
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
      ),
    );
  }
}